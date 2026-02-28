import SwiftUI

struct SettingsView: View {
    @State private var config = ConfigService.shared
    @State private var selectedTab: SettingsTab = .basic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tune engine, speed limits, startup, and security options")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .basic:
                        basicTab
                            .transition(.opacity)
                    case .advanced:
                        advancedTab
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(white: 0.18, alpha: 1)),
                    Color(nsColor: NSColor(white: 0.15, alpha: 1))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(.dark)
    }

    private var basicTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSection("Download") {
                HStack {
                    Text("Save to")
                    Spacer()
                    Text(config.downloadDir)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Browse") { pickDirectory() }
                }
                Stepper("Max concurrent: \(config.maxConcurrentDownloads)", value: $config.maxConcurrentDownloads, in: 1...20)
                Stepper("Connections per server: \(config.maxConnectionPerServer)", value: $config.maxConnectionPerServer, in: 1...16)
            }

            settingsSection("Behavior") {
                Toggle("Resume all on launch", isOn: $config.resumeAllOnLaunch)
                Toggle("Show notifications", isOn: $config.taskNotification)
                Toggle("Show speed in Dock", isOn: $config.showProgressBar)
            }

            settingsSection("System") {
                Toggle("Start at login", isOn: $config.openAtLogin)
                Toggle("Tray speedometer", isOn: $config.traySpeedometer)
                Toggle("Auto check updates", isOn: $config.autoCheckUpdate)
            }
        }
    }

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSection("Speed Limits") {
                HStack {
                    Text("Download limit")
                    Spacer()
                    TextField("0 = unlimited", value: $config.maxOverallDownloadLimit, format: .number)
                        .frame(width: 100)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Upload limit")
                    Spacer()
                    TextField("0 = unlimited", value: $config.maxOverallUploadLimit, format: .number)
                        .frame(width: 100)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }
            }

            settingsSection("BitTorrent") {
                Toggle("Keep seeding", isOn: $config.keepSeeding)
                if !config.keepSeeding {
                    HStack {
                        Text("Seed ratio")
                        Spacer()
                        TextField("2.0", value: $config.seedRatio, format: .number)
                            .frame(width: 60)
                    }
                    Stepper("Seed time: \(config.seedTime) min", value: $config.seedTime, in: 0...14400, step: 60)
                }
                Toggle("Auto sync trackers", isOn: $config.autoSyncTracker)
                Toggle("Enable UPnP", isOn: $config.enableUPnP)
            }

            settingsSection("Security") {
                HStack {
                    Text("RPC Secret")
                    Spacer()
                    SecureField("Optional", text: $config.rpcSecret)
                        .frame(width: 150)
                }
            }
        }
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            config.downloadDir = url.path
        }
    }
}

private extension SettingsView {
    enum SettingsTab: CaseIterable {
        case basic
        case advanced

        var title: String {
            switch self {
            case .basic: return "Basic"
            case .advanced: return "Advanced"
            }
        }

        var icon: String {
            switch self {
            case .basic: return "gearshape"
            case .advanced: return "gearshape.2"
            }
        }
    }

    @ViewBuilder
    func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
