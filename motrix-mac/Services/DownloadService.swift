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
    var state: AppState

    init(state: AppState) {
        self.state = state
    }

    func connect(port: UInt16 = Aria2Config.rpcPort, secret: String? = nil) {
        client = Aria2(ssl: false, host: Aria2Config.rpcHost, port: port, token: secret)
        rpcAvailable = true
        rpcUnavailableSince = nil
        logger.info("connected to aria2 at \(Aria2Config.rpcHost):\(port)")
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
        await fetchGlobalStat()
        await fetchTaskList()
        state.adjustPollingInterval()
    }

    @MainActor
    func fetchGlobalStat() async {
        guard let client else { return }
        do {
            let response: [String: Any] = try await call(client: client, method: .getGlobalStat)
            state.globalStat = GlobalStat.from(response)
            markRPCAvailable()
        } catch {
            markRPCUnavailable(error: error)
        }
    }

    @MainActor
    func fetchTaskList() async {
        guard let client else { return }
        do {
            let method: Aria2Method
            switch state.currentList {
            case .active:
                let active: [[String: Any]] = try await call(client: client, method: .tellActive)
                let waiting: [[String: Any]] = try await callWithParams(client: client, method: .tellWaiting, params: [AnyEncodable(0), AnyEncodable(50)])
                state.tasks = (active + waiting).map { DownloadTask.from($0) }
                markRPCAvailable()
                return
            case .completed, .stopped:
                method = .tellStopped
            }
            let result: [[String: Any]] = try await callWithParams(client: client, method: method, params: [AnyEncodable(0), AnyEncodable(50)])
            state.tasks = result.map { DownloadTask.from($0) }
            markRPCAvailable()
        } catch {
            markRPCUnavailable(error: error)
        }
    }

    func addUri(uris: [String], options: [String: String] = [:]) async throws {
        guard let client else { return }
        let _: String = try await callWithParams(
            client: client,
            method: .addUri,
            params: [AnyEncodable(uris), AnyEncodable(options)]
        )
        await refresh()
    }

    func addTorrent(data: Data, options: [String: String] = [:]) async throws {
        guard let client else { return }
        let base64 = data.base64EncodedString()
        let _: String = try await callWithParams(
            client: client,
            method: .addTorrent,
            params: [AnyEncodable(base64), AnyEncodable([String]()), AnyEncodable(options)]
        )
        await refresh()
    }

    func pauseTask(gid: String) async throws {
        guard let client else { return }
        let _: String = try await callWithParams(client: client, method: .pause, params: [AnyEncodable(gid)])
        await refresh()
    }

    func resumeTask(gid: String) async throws {
        guard let client else { return }
        let _: String = try await callWithParams(client: client, method: .unpause, params: [AnyEncodable(gid)])
        await refresh()
    }

    func removeTask(gid: String) async throws {
        guard let client else { return }
        let _: String = try await callWithParams(client: client, method: .forceRemove, params: [AnyEncodable(gid)])
        await refresh()
    }

    func removeTaskRecord(gid: String) async throws {
        guard let client else { return }
        let _: String = try await callWithParams(client: client, method: .removeDownloadResult, params: [AnyEncodable(gid)])
        await refresh()
    }

    func pauseAll() async throws {
        guard let client else { return }
        let _: String = try await call(client: client, method: .forcePauseAll)
        await refresh()
    }

    func resumeAll() async throws {
        guard let client else { return }
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

    func changeGlobalOption(_ options: [String: String]) async {
        guard let client else { return }
        let _: String? = try? await callWithParams(client: client, method: .changeGlobalOption, params: [AnyEncodable(options)])
    }

    private func call<T>(client: Aria2, method: Aria2Method) async throws -> T {
        try await callWithParams(client: client, method: method, params: [])
    }

    private func callWithParams<T>(client: Aria2, method: Aria2Method, params: [AnyEncodable] = []) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            client.call(method: method, params: params)
                .validate()
                .responseData { response in
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
}

enum DownloadServiceError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from aria2"
        }
    }
}
