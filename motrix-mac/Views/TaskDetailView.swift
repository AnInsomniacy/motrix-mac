import SwiftUI

struct TaskDetailView: View {
    let task: DownloadTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)

            Divider().opacity(0.3)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressSection
                    filesSection
                    infoSection
                }
                .padding(20)
            }
        }
        .frame(width: 480)
        .frame(minHeight: 380)
        .background(Color(nsColor: NSColor(white: 0.16, alpha: 1)))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            FileTypeIcon(extension_: task.files.first?.fileExtension ?? "")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(task.status.rawValue.capitalized)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .controlSize(.small)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor)
                        .frame(width: max(0, geo.size.width * task.progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Text("\(ByteFormatter.format(task.completedLength)) / \(ByteFormatter.format(task.totalLength))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 16) {
                SpeedBadge(speed: task.downloadSpeed, direction: .download)
                SpeedBadge(speed: task.uploadSpeed, direction: .upload)
                if !task.remaining.isEmpty {
                    Text("ETA: \(task.remaining)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Text("\(task.connections) connections")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FILES (\(task.files.count))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(task.files) { file in
                HStack(spacing: 8) {
                    FileTypeIcon(extension_: file.fileExtension)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.fileName)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Text(ByteFormatter.format(file.length))
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if file.length > 0 {
                        let p = Double(file.completedLength) / Double(file.length)
                        Text("\(Int(p * 100))%")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DETAILS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                row("GID", task.gid)
                row("Directory", task.dir)
                if let hash = task.infoHash { row("Info Hash", hash) }
                if task.isBT { row("Seeders", "\(task.numSeeders)") }
                if let code = task.errorCode, let msg = task.errorMessage {
                    row("Error", "\(code): \(msg)")
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .active: return .blue
        case .waiting, .paused: return .orange
        case .complete: return .green
        case .error: return .red
        case .removed: return .gray
        }
    }
}
