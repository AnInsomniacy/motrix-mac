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

            HStack(spacing: 8) {
                settingsTabButton(.basic)
                settingsTabButton(.advanced)
            }
            .frame(maxWidth: 280)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .basic:
                        basicCards
                            .transition(.opacity)
                    case .advanced:
                        advancedCards
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                .padding(16)
            }
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

    private var basicCards: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                settingsCard(icon: "folder", title: "Save Location") {
                    Text(config.downloadDir)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Button("Browse") { pickDirectory() }
                        .buttonStyle(MotrixButtonStyle(prominent: false))
                }

                settingsCard(icon: "bell", title: "Behavior") {
                    settingsRow("Resume on launch") {
                        Toggle("", isOn: $config.resumeAllOnLaunch).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().opacity(0.3)
                    settingsRow("Notifications") {
                        Toggle("", isOn: $config.taskNotification).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().opacity(0.3)
                    settingsRow("Speed in Dock") {
                        Toggle("", isOn: $config.showProgressBar).toggleStyle(.switch).labelsHidden()
                    }
                }
            }

            VStack(spacing: 12) {
                settingsCard(icon: "arrow.down.circle", title: "Connections") {
                    settingsRow("Max concurrent") {
                        Stepper("\(config.maxConcurrentDownloads)", value: $config.maxConcurrentDownloads, in: 1...20)
                    }
                    Divider().opacity(0.3)
                    settingsRow("Per server") {
                        Stepper("\(config.maxConnectionPerServer)", value: $config.maxConnectionPerServer, in: 1...16)
                    }
                }

                settingsCard(icon: "desktopcomputer", title: "System") {
                    settingsRow("Language") {
                        Picker("", selection: $config.appLanguage) {
                            Text("System").tag("system")
                            Text("English").tag("en")
                            Text("简体中文").tag("zh-Hans")
                            Text("日本語").tag("ja")
                        }
                        .labelsHidden()
                        .frame(width: 100)
                        .onChange(of: config.appLanguage) { _, newValue in
                            if newValue == "system" {
                                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                            } else {
                                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                            }
                        }
                    }
                    Divider().opacity(0.3)
                    settingsRow("Start at login") {
                        Toggle("", isOn: $config.openAtLogin).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().opacity(0.3)
                    settingsRow("Tray speedometer") {
                        Toggle("", isOn: $config.traySpeedometer).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().opacity(0.3)
                    settingsRow("Auto updates") {
                        Toggle("", isOn: $config.autoCheckUpdate).toggleStyle(.switch).labelsHidden()
                    }
                }
            }
        }
    }

    private var advancedCards: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                settingsCard(icon: "speedometer", title: "Speed Limits") {
                    settingsRow("Enable") {
                        Toggle("", isOn: $config.speedLimitEnabled).toggleStyle(.switch).labelsHidden()
                    }
                    if config.speedLimitEnabled {
                        Divider().opacity(0.3)
                        settingsRow("Download") {
                            HStack(spacing: 4) {
                                TextField("0", value: $config.maxOverallDownloadLimit, format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                Text("KB/s")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        Divider().opacity(0.3)
                        settingsRow("Upload") {
                            HStack(spacing: 4) {
                                TextField("0", value: $config.maxOverallUploadLimit, format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                Text("KB/s")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    } else {
                        Divider().opacity(0.3)
                        settingsRow("Status") {
                            Text("Unlimited")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }

                settingsCard(icon: "lock.shield", title: "Security") {
                    settingsRow("RPC Secret") {
                        SecureField("Auto-generated", text: $config.rpcSecret)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 120)
                    }
                }
            }

            VStack(spacing: 12) {
                settingsCard(icon: "point.3.connected.trianglepath.dotted", title: "BitTorrent") {
                    settingsRow("Keep seeding") {
                        Toggle("", isOn: $config.keepSeeding).toggleStyle(.switch).labelsHidden()
                    }
                    if !config.keepSeeding {
                        Divider().opacity(0.3)
                        settingsRow("Seed ratio") {
                            HStack(spacing: 3) {
                                TextField("2.0", value: $config.seedRatio, format: .number)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .frame(width: 40)
                                    .multilineTextAlignment(.trailing)
                                Text("×")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        Divider().opacity(0.3)
                        settingsRow("Seed time") {
                            Stepper("\(config.seedTime) min", value: $config.seedTime, in: 0...14400, step: 60)
                                .font(.system(size: 12))
                        }
                    }
                    Divider().opacity(0.3)
                    settingsRow("Sync trackers") {
                        Toggle("", isOn: $config.autoSyncTracker).toggleStyle(.switch).labelsHidden()
                    }
                    Divider().opacity(0.3)
                    settingsRow("UPnP") {
                        Toggle("", isOn: $config.enableUPnP).toggleStyle(.switch).labelsHidden()
                    }
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

    @ViewBuilder
    private func settingsCard<Content: View>(icon: String, title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.blue.opacity(0.9))
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func settingsRow<Content: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            content()
        }
    }

    private func settingsTabButton(_ tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
                Text(tab.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.white.opacity(0.11) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selectedTab == tab ? Color.white.opacity(0.2) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private extension SettingsView {
    enum SettingsTab: CaseIterable {
        case basic
        case advanced

        var title: LocalizedStringKey {
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
}
