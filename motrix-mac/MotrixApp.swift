import SwiftUI
import os

@main
struct MotrixApp: App {
    @State private var appState = AppState()
    @State private var engine = Aria2Process()
    @State private var downloadService: DownloadService
    @State private var engineWatchdogTask: Task<Void, Never>?
    @State private var dockBadgeTask: Task<Void, Never>?
    private let protocolService = ProtocolService()
    private let trackerService = TrackerService()
    private let logger = Logger(subsystem: "app.motrix", category: "App")

    init() {
        let state = AppState()
        _appState = State(initialValue: state)
        _downloadService = State(initialValue: DownloadService(state: state))
    }

    var body: some Scene {
        WindowGroup {
            MainWindow(downloadService: downloadService)
                .environment(appState)
                .onAppear { startup() }
                .onDisappear { shutdown() }
                .handlesExternalEvents(preferring: ["motrix"], allowing: ["*"])
                .onOpenURL { url in handleURL(url) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") { appState.currentSection = .add }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .newItem) {
                Button("Resume All") { Task { try? await downloadService.resumeAll() } }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Pause All") { Task { try? await downloadService.pauseAll() } }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(.dark)
        }

        MenuBarExtra {
            MenuBarView(downloadService: downloadService)
                .environment(appState)
        } label: {
            Label("Motrix", systemImage: "arrow.down.circle")
        }
        .menuBarExtraStyle(.window)
    }

    private func startup() {
        Task {
            let started = await bootEngineAndConnect()
            if started {
                if ConfigService.shared.resumeAllOnLaunch {
                    try? await downloadService.resumeAll()
                }
                if ConfigService.shared.autoSyncTracker {
                    syncTrackers()
                }
            }
        }
        startEngineWatchdog()

        startDockBadgeUpdater()
    }

    private func shutdown() {
        engineWatchdogTask?.cancel()
        engineWatchdogTask = nil
        dockBadgeTask?.cancel()
        dockBadgeTask = nil
        Task {
            await downloadService.saveSession()
            await downloadService.shutdown()
        }
        downloadService.stopPolling()
        engine.stop()
        NSApp.dockTile.badgeLabel = nil
    }

    private func startDockBadgeUpdater() {
        dockBadgeTask?.cancel()
        dockBadgeTask = Task { @MainActor in
            while !Task.isCancelled {
                if ConfigService.shared.showProgressBar {
                    let speed = appState.globalStat.downloadSpeed
                    NSApp.dockTile.badgeLabel = speed > 0 ? ByteFormatter.speed(speed) : nil
                } else {
                    NSApp.dockTile.badgeLabel = nil
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func syncTrackers() {
        Task {
            let trackers = await trackerService.fetchTrackers()
            if !trackers.isEmpty {
                await downloadService.changeGlobalOption(["bt-tracker": trackers])
                logger.info("synced \(trackers.components(separatedBy: ",").count) trackers")
            }
        }
    }

    private func handleURL(_ url: URL) {
        guard let parsed = protocolService.parseURL(url) else { return }
        switch parsed {
        case .download(let uri):
            appState.addTaskURL = uri
            appState.currentSection = .add
        case .command:
            break
        }
    }

    private func waitForRPCReady(secret: String?) async -> Bool {
        try? await Task.sleep(for: .milliseconds(500))
        for _ in 0..<30 {
            if await isRPCReady(secret: secret) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return false
    }

    private func isRPCReady(secret: String?) async -> Bool {
        guard let url = URL(string: "http://\(Aria2Config.rpcHost):\(Aria2Config.rpcPort)/jsonrpc") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var params: [Any] = []
        if let secret, !secret.isEmpty {
            params.append("token:\(secret)")
        }
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": "startup",
            "method": "aria2.getVersion",
            "params": params
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        request.httpBody = body
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
            return json["result"] != nil
        } catch {
            return false
        }
    }

    private func startEngineWatchdog() {
        engineWatchdogTask?.cancel()
        engineWatchdogTask = Task {
            while !Task.isCancelled {
                if !engine.isRunning || downloadService.shouldRecoverRPCStall(timeout: 8) {
                    logger.error("aria2 unhealthy, attempting restart")
                    downloadService.stopPolling()
                    engine.stop()
                    _ = await bootEngineAndConnect()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func bootEngineAndConnect() async -> Bool {
        let engineOptions: [String: Any] = ConfigService.shared.aria2SystemConfig().reduce(into: [:]) { partialResult, pair in
            partialResult[pair.key] = pair.value
        }
        do {
            try engine.start(extraArgs: engineOptions)
            logger.info("aria2c engine started")
        } catch {
            logger.error("failed to start aria2c: \(error.localizedDescription)")
            return false
        }
        let rawSecret = ConfigService.shared.rpcSecret
        let secret = rawSecret.isEmpty ? nil : rawSecret
        let rpcReady = await waitForRPCReady(secret: secret)
        if !rpcReady {
            logger.error("aria2 rpc is not ready after startup timeout")
            engine.stop()
            return false
        }
        downloadService.connect(secret: secret)
        downloadService.startPolling()
        return true
    }
}

#Preview {
    let state = AppState()
    let service = DownloadService(state: state)
    MainWindow(downloadService: service)
        .environment(state)
        .frame(width: 900, height: 600)
        .preferredColorScheme(.dark)
}
