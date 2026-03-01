import SwiftUI

struct TaskRowView: View {
    let task: DownloadTask
    let isSelected: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.25))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(task.name)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Spacer()

                    if isHovered {
                        HStack(spacing: 4) {
                            if task.status == .active || task.status == .waiting || task.status == .paused {
                                actionBtn(task.status == .active ? "pause.fill" : "play.fill", onToggle)
                            }
                            if task.status == .complete {
                                actionBtn("folder", { openInFinder() })
                            }
                            actionBtn("trash", onRemove)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressTrackColor)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(progressColor)
                                .frame(width: max(0, geo.size.width * task.progress), height: 4)
                                .animation(.easeInOut(duration: 0.3), value: task.progress)
                        }
                    }
                    .frame(height: 4)

                    HStack(spacing: 0) {
                        progressInfo
                        Spacer()
                        speedInfo
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                    ? Color.blue.opacity(0.08)
                    : Color(nsColor: NSColor(white: 0.18, alpha: 1)))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isSelected ? Color.blue.opacity(0.3)
                            : isHovered ? Color.white.opacity(0.15)
                            : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { isHovered = h } }
    }

    private func actionBtn(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
        }
        .buttonStyle(MotrixIconButtonStyle())
    }

    private var progressInfo: some View {
        HStack(spacing: 6) {
            if task.totalLength > 0 {
                Text("\(ByteFormatter.format(task.completedLength))/\(ByteFormatter.format(task.totalLength))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if task.status == .complete {
                Text("Complete")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.green)
            }
            if task.status == .error {
                Text(task.errorMessage ?? "Error")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            if task.isSeeding {
                Text("Seeding")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.mint)
            }
        }
    }

    private var speedInfo: some View {
        HStack(spacing: 8) {
            if task.status == .active || task.status == .waiting || task.status == .paused {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(ByteFormatter.speed(task.downloadSpeed))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(task.downloadSpeed > 0 ? .blue : .secondary)

                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                    Text(ByteFormatter.speed(task.uploadSpeed))
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(task.uploadSpeed > 0 ? .green : .secondary)

                if !task.remaining.isEmpty {
                    Text(task.remaining)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                Text("\(task.connections) connections")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progressColor: Color {
        switch task.status {
        case .active: return .blue
        case .paused, .waiting: return .orange
        case .complete: return .green
        case .error: return .red
        case .removed: return .gray
        }
    }

    private var progressTrackColor: Color {
        Color.white.opacity(0.06)
    }

    private func openInFinder() {
        let path = task.dir
        if !path.isEmpty {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }
}
