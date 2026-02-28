import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var state
    let downloadService: DownloadService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.blue)
                    Text(ByteFormatter.speed(state.globalStat.downloadSpeed))
                        .font(.system(size: 12, design: .monospaced))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                    Text(ByteFormatter.speed(state.globalStat.uploadSpeed))
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider().padding(.horizontal, 8)

            if !state.activeTasks.isEmpty {
                ForEach(state.activeTasks.prefix(5)) { task in
                    HStack {
                        Text(task.name)
                            .lineLimit(1)
                            .font(.system(size: 11))
                        Spacer()
                        Text("\(Int(task.progress * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
                Divider().padding(.horizontal, 8)
            }

            Button("Resume All") { Task { try? await downloadService.resumeAll() } }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
            Button("Pause All") { Task { try? await downloadService.pauseAll() } }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)

            Divider().padding(.horizontal, 8)

            Button("Quit Motrix") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .padding(.bottom, 4)
        }
        .frame(width: 280)
    }
}
