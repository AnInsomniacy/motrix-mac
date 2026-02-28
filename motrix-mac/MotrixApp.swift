import SwiftUI
import os
import ServiceManagement
import UserNotifications

@main
struct MotrixApp: App {
    @State private var appState = AppState()
    @State private var engine = Aria2Process()
    @State private var downloadService: DownloadService
    @State private var engineWatchdogTask: Task<Void, Never>?
    @State private var dockBadgeTask: Task<Void, Never>?
    @State private var settingsSyncTask: Task<Void, Never>?
    @State private var lastAppliedSettings = AppliedSettingsSnapshot()
    @State private var didRunAutoUpdateCheck = false
    @State private var hasStarted = false
    @State private var isBootingEngine = false
    private let protocolService = ProtocolService()
    private let trackerService = TrackerService()
    private let upnpService = UPnPService()
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
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    shutdown()
                }
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
                Button("Resume All") {
                    Task {
                        do {
                            try await downloadService.resumeAll()
                        } catch {
                            appState.presentError("Resume all failed: \(error.localizedDescription)")
                        }
                    }
                }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Pause All") {
                    Task {
                        do {
                            try await downloadService.pauseAll()
                        } catch {
                            appState.presentError("Pause all failed: \(error.localizedDescription)")
                        }
                    }
                }
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
        guard !hasStarted else { return }
        hasStarted = true
        downloadService.onTaskTerminalUpdate = { task in
            Task { @MainActor in
                await notifyTaskTerminalUpdate(task)
            }
        }
        Task {
            let started = await bootEngineAndConnect()
            if started {
                await applySettingsSnapshot(force: true)
                if ConfigService.shared.resumeAllOnLaunch {
                    do {
                        try await downloadService.resumeAll()
                    } catch {
                        await MainActor.run {
                            appState.presentError("Resume all on launch failed: \(error.localizedDescription)")
                        }
                    }
                }
                if ConfigService.shared.autoSyncTracker {
                    syncTrackers()
                }
                if ConfigService.shared.enableUPnP {
                    await upnpService.mapPort(Aria2Config.rpcPort)
                }
            }
            startSettingsSync()
            startEngineWatchdog()
        }
        startDockBadgeUpdater()
    }

    private func shutdown() {
        guard hasStarted else { return }
        hasStarted = false
        engineWatchdogTask?.cancel()
        engineWatchdogTask = nil
        dockBadgeTask?.cancel()
        dockBadgeTask = nil
        settingsSyncTask?.cancel()
        settingsSyncTask = nil
        Task {
            await downloadService.saveSession()
            await downloadService.shutdown()
            await upnpService.unmapPort()
        }
        downloadService.stopPolling()
        downloadService.disconnect()
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
                do {
                    try await downloadService.changeGlobalOption(["bt-tracker": trackers])
                    logger.info("synced \(trackers.components(separatedBy: ",").count) trackers")
                } catch {
                    logger.warning("tracker sync apply failed: \(error.localizedDescription)")
                }
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
                if isBootingEngine {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                if !downloadService.isConnected || downloadService.shouldRecoverRPCStall(timeout: 8) {
                    logger.error("aria2 unhealthy, attempting restart")
                    downloadService.stopPolling()
                    downloadService.disconnect()
                    engine.stop()
                    _ = await bootEngineAndConnect()
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func bootEngineAndConnect() async -> Bool {
        isBootingEngine = true
        defer { isBootingEngine = false }
        let rawSecret = ConfigService.shared.rpcSecret
        let secret = rawSecret.isEmpty ? nil : rawSecret

        if await isRPCReady(secret: secret) {
            logger.info("aria2 rpc already available, attaching without spawning new process")
            downloadService.connect(secret: secret)
            downloadService.startPolling()
            return true
        }

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

    private func startSettingsSync() {
        settingsSyncTask?.cancel()
        settingsSyncTask = Task { @MainActor in
            while !Task.isCancelled {
                await applySettingsSnapshot(force: false)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @MainActor
    private func applySettingsSnapshot(force: Bool) async {
        let config = ConfigService.shared
        let snapshot = AppliedSettingsSnapshot(
            openAtLogin: config.openAtLogin,
            enableUPnP: config.enableUPnP,
            traySpeedometer: config.traySpeedometer,
            showProgressBar: config.showProgressBar,
            autoCheckUpdate: config.autoCheckUpdate,
            taskNotification: config.taskNotification,
            runtimeOptions: config.aria2RuntimeOptions()
        )
        if !force && snapshot == lastAppliedSettings { return }
        var applied = lastAppliedSettings

        if force || snapshot.openAtLogin != lastAppliedSettings.openAtLogin {
            if applyOpenAtLogin(snapshot.openAtLogin) {
                applied.openAtLogin = snapshot.openAtLogin
            }
        }
        if force || snapshot.runtimeOptions != lastAppliedSettings.runtimeOptions {
            if downloadService.isConnected {
                do {
                    try await downloadService.changeGlobalOption(snapshot.runtimeOptions)
                    applied.runtimeOptions = snapshot.runtimeOptions
                } catch {
                    logger.warning("apply global options failed: \(error.localizedDescription)")
                }
            }
        }
        if force || snapshot.enableUPnP != lastAppliedSettings.enableUPnP {
            if snapshot.enableUPnP {
                await upnpService.mapPort(Aria2Config.rpcPort)
            } else {
                await upnpService.unmapPort()
            }
            applied.enableUPnP = snapshot.enableUPnP
        }
        if snapshot.autoCheckUpdate && (!didRunAutoUpdateCheck || force) {
            didRunAutoUpdateCheck = true
            Task { await checkForUpdatesIfNeeded() }
        }
        applied.traySpeedometer = snapshot.traySpeedometer
        applied.showProgressBar = snapshot.showProgressBar
        applied.autoCheckUpdate = snapshot.autoCheckUpdate
        applied.taskNotification = snapshot.taskNotification
        lastAppliedSettings = applied
    }

    private func applyOpenAtLogin(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return true }
        guard canManageLoginItem else {
            if enabled {
                ConfigService.shared.openAtLogin = false
            }
            return false
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            logger.error("openAtLogin apply failed: \(error.localizedDescription)")
            if enabled {
                ConfigService.shared.openAtLogin = false
                appState.presentError("Start at login requires a properly signed app context. It is unavailable in the current run environment.")
            }
            return false
        }
    }

    private var canManageLoginItem: Bool {
        let bundleURL = Bundle.main.bundleURL
        let appPath = bundleURL.path
        if appPath.contains("/DerivedData/") { return false }
        if appPath.contains("/Xcode/Previews/") { return false }
        if !appPath.hasSuffix(".app") { return false }
        return true
    }

    private func checkForUpdatesIfNeeded() async {
        guard ConfigService.shared.autoCheckUpdate else { return }
        guard let url = URL(string: "https://api.github.com/repos/agalwood/Motrix/releases/latest") else { return }
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else { return }
            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            if isVersion(latest, newerThan: current) {
                await notify(
                    title: "Update Available",
                    body: "New version \(latest) is available. Current version: \(current).",
                    respectTaskNotification: false
                )
            }
        } catch {
            logger.warning("update check failed: \(error.localizedDescription)")
        }
    }

    private func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let l = lhs.split(separator: ".").compactMap { Int($0) }
        let r = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(l.count, r.count)
        for i in 0..<count {
            let lv = i < l.count ? l[i] : 0
            let rv = i < r.count ? r[i] : 0
            if lv != rv { return lv > rv }
        }
        return false
    }

    @MainActor
    private func notifyTaskTerminalUpdate(_ task: DownloadTask) async {
        guard ConfigService.shared.taskNotification else { return }
        switch task.status {
        case .complete:
            await notify(title: "Download Completed", body: task.name)
        case .error:
            let message = task.errorMessage ?? "Task failed"
            await notify(title: "Download Failed", body: "\(task.name): \(message)")
        default:
            break
        }
    }

    private func notify(title: String, body: String, respectTaskNotification: Bool = true) async {
        if respectTaskNotification && !ConfigService.shared.taskNotification { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}

private struct AppliedSettingsSnapshot: Equatable {
    var openAtLogin = false
    var enableUPnP = true
    var traySpeedometer = true
    var showProgressBar = true
    var autoCheckUpdate = true
    var taskNotification = true
    var runtimeOptions: [String: String] = [:]
}

#Preview {
    let state = AppState()
    let service = DownloadService(state: state)
    MainWindow(downloadService: service)
        .environment(state)
        .frame(width: 900, height: 600)
        .preferredColorScheme(.dark)
}
