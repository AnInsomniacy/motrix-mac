import Foundation
import Alamofire
import Aria2Kit
import AnyCodable
import os

@Observable
final class DownloadService {
    private let logger = Logger(subsystem: "app.motrix", category: "DownloadService")
    private var client: Aria2?
    private var pollingTask: Task<Void, Never>?
    private var rpcAvailable = true
    private var rpcUnavailableSince: Date?
    private let listPageSize = 500
    private var terminalStatusSnapshot: [String: TaskStatus] = [:]
    private var didBootstrapTerminalSnapshot = false
    var onTaskTerminalUpdate: ((DownloadTask) -> Void)?
    var state: AppState
    var isConnected: Bool { client != nil }

    init(state: AppState) {
        self.state = state
    }

    func connect(port: UInt16 = Aria2Config.rpcPort, secret: String? = nil) {
        client = Aria2(ssl: false, host: Aria2Config.rpcHost, port: port, token: secret)
        rpcAvailable = true
        rpcUnavailableSince = nil
        logger.info("connected to aria2 at \(Aria2Config.rpcHost):\(port)")
    }

    func disconnect() {
        client = nil
        rpcAvailable = true
        rpcUnavailableSince = nil
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = self?.state.pollingInterval ?? 1.0
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @MainActor
    func refresh() async {
        guard let client else { return }
        do {
            let snapshot = try await fetchSnapshotOffMain(client: client)
            state.globalStat = snapshot.globalStat
            state.completedCount = snapshot.completed.count
            state.stoppedCount = snapshot.stopped.count
            state.replaceTaskIndex(with: snapshot.indexed)
            state.allActive = snapshot.active
            state.allCompleted = snapshot.completed
            state.allStopped = snapshot.stopped
            processTerminalEvents(snapshot.completed + snapshot.stopped)
            state.adjustPollingInterval()
            markRPCAvailable()
        } catch {
            markRPCUnavailable(error: error)
            state.adjustPollingInterval()
        }
    }

    private struct TaskSnapshot {
        let globalStat: GlobalStat
        let active: [DownloadTask]
        let completed: [DownloadTask]
        let stopped: [DownloadTask]
        let indexed: [DownloadTask]
    }

    nonisolated private func fetchSnapshotOffMain(client: Aria2) async throws -> TaskSnapshot {
        let statResponse: [String: Any] = try await call(client: client, method: .getGlobalStat)
        let globalStat = GlobalStat.from(statResponse)

        let activeRaw: [[String: Any]] = try await call(client: client, method: .tellActive)
        let waitingRaw: [[String: Any]] = try await fetchPagedEntries(client: client, method: .tellWaiting)
        let stoppedRaw: [[String: Any]] = try await fetchPagedEntries(client: client, method: .tellStopped)

        let active = (activeRaw + waitingRaw).map { DownloadTask.from($0) }
        let stoppedAll = stoppedRaw.map { DownloadTask.from($0) }
        let completed = stoppedAll.filter { $0.status == .complete }
        let stopped = stoppedAll.filter { $0.status == .error || $0.status == .removed }

        var taskMap: [String: DownloadTask] = [:]
        for task in stoppedAll { taskMap[task.gid] = task }
        for task in active { taskMap[task.gid] = task }

        return TaskSnapshot(
            globalStat: globalStat,
            active: active,
            completed: completed,
            stopped: stopped,
            indexed: Array(taskMap.values)
        )
    }

    nonisolated private func fetchPagedEntries(client: Aria2, method: Aria2Method) async throws -> [[String: Any]] {
        var result: [[String: Any]] = []
        var offset = 0
        while true {
            let page: [[String: Any]] = try await callWithParams(
                client: client,
                method: method,
                params: [AnyEncodable(offset), AnyEncodable(listPageSize)]
            )
            if page.isEmpty { break }
            result.append(contentsOf: page)
            if page.count < listPageSize { break }
            let previousOffset = offset
            offset += page.count
            if offset <= previousOffset { break }
        }
        return result
    }

    func addUri(uris: [String], options: [String: String] = [:]) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(
            client: client,
            method: .addUri,
            params: [AnyEncodable(uris), AnyEncodable(options)]
        )
        await refresh()
    }

    func addTorrent(data: Data, options: [String: String] = [:]) async throws {
        let client = try requireClient()
        let base64 = data.base64EncodedString()
        let _: String = try await callWithParams(
            client: client,
            method: .addTorrent,
            params: [AnyEncodable(base64), AnyEncodable([String]()), AnyEncodable(options)]
        )
        await refresh()
    }

    func pauseTask(gid: String) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(client: client, method: .pause, params: [AnyEncodable(gid)])
        await refresh()
    }

    func resumeTask(gid: String) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(client: client, method: .unpause, params: [AnyEncodable(gid)])
        await refresh()
    }

    func removeTask(gid: String) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(client: client, method: .forceRemove, params: [AnyEncodable(gid)])
        await refresh()
    }

    func removeTaskRecord(gid: String) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(client: client, method: .removeDownloadResult, params: [AnyEncodable(gid)])
        await refresh()
    }

    func pauseAll() async throws {
        let client = try requireClient()
        let _: String = try await call(client: client, method: .forcePauseAll)
        await refresh()
    }

    func resumeAll() async throws {
        let client = try requireClient()
        let _: String = try await call(client: client, method: .unpauseAll)
        await refresh()
    }

    func saveSession() async {
        guard let client else { return }
        let _: String? = try? await call(client: client, method: .saveSession)
    }

    func shutdown(force: Bool = true) async {
        guard let client else { return }
        let method: Aria2Method = force ? .forceShutdown : .shutdown
        let _: String? = try? await call(client: client, method: method)
    }

    func changeGlobalOption(_ options: [String: String]) async throws {
        let client = try requireClient()
        let _: String = try await callWithParams(client: client, method: .changeGlobalOption, params: [AnyEncodable(options)])
    }

    private func requireClient() throws -> Aria2 {
        guard let client else {
            throw DownloadServiceError.notConnected
        }
        return client
    }

    nonisolated private func call<T>(client: Aria2, method: Aria2Method) async throws -> T {
        try await callWithParams(client: client, method: method, params: [])
    }

    nonisolated private static let rpcResponseQueue = DispatchQueue(label: "app.motrix.rpc.response", qos: .userInitiated)

    nonisolated private func callWithParams<T>(client: Aria2, method: Aria2Method, params: [AnyEncodable] = []) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            client.call(method: method, params: params)
                .validate()
                .responseData(queue: Self.rpcResponseQueue) { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  let result = json["result"] as? T else {
                                continuation.resume(throwing: DownloadServiceError.invalidResponse)
                                return
                            }
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
        }
    }

    private func markRPCAvailable() {
        if !rpcAvailable {
            logger.info("aria2 rpc recovered")
        }
        rpcAvailable = true
        rpcUnavailableSince = nil
    }

    private func markRPCUnavailable(error: Error) {
        if rpcAvailable {
            logger.error("aria2 rpc unavailable: \(error.localizedDescription)")
            rpcUnavailableSince = Date()
        }
        rpcAvailable = false
        state.globalStat.downloadSpeed = 0
        state.globalStat.uploadSpeed = 0
    }

    func shouldRecoverRPCStall(timeout: TimeInterval) -> Bool {
        guard let since = rpcUnavailableSince else { return false }
        return Date().timeIntervalSince(since) >= timeout
    }

    @MainActor
    private func processTerminalEvents(_ tasks: [DownloadTask]) {
        let current = Dictionary(uniqueKeysWithValues: tasks.map { ($0.gid, $0.status) })
        defer {
            terminalStatusSnapshot = current
            didBootstrapTerminalSnapshot = true
        }
        guard didBootstrapTerminalSnapshot else { return }
        for task in tasks {
            guard task.status == .complete || task.status == .error else { continue }
            let previous = terminalStatusSnapshot[task.gid]
            if previous != task.status {
                onTaskTerminalUpdate?(task)
            }
        }
    }
}

enum DownloadServiceError: LocalizedError {
    case invalidResponse
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from aria2"
        case .notConnected: return "Aria2 RPC is not connected"
        }
    }
}
