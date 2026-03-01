import SwiftUI

struct TaskDetailView: View {
    let task: DownloadTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task Detail")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                detailSection("Name") {
                    Text(task.name)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .textSelection(.enabled)
                }

                Divider().opacity(0.2)

                HStack(spacing: 24) {
                    detailItem("Status", statusText)
                    detailItem("GID", task.gid)
                }

                Divider().opacity(0.2)

                HStack(spacing: 24) {
                    detailItem("Total", ByteFormatter.format(task.totalLength))
                    detailItem("Downloaded", ByteFormatter.format(task.completedLength))
                    if task.uploadLength > 0 {
                        detailItem("Uploaded", ByteFormatter.format(task.uploadLength))
                    }
                }

                Divider().opacity(0.2)

                detailSection("Save Path") {
                    Text(task.dir)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .textSelection(.enabled)
                }

                if !task.files.isEmpty {
                    Divider().opacity(0.2)
                    detailSection("Files (\(task.files.count))") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(task.files) { file in
                                HStack(spacing: 6) {
                                    Image(systemName: fileIcon(file.fileExtension))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 14)
                                    Text(file.fileName)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Text(ByteFormatter.format(file.length))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                }

                if task.isBT {
                    Divider().opacity(0.2)
                    HStack(spacing: 24) {
                        if let hash = task.infoHash {
                            detailItem("Info Hash", String(hash.prefix(16)) + "…")
                        }
                        detailItem("Seeders", "\(task.numSeeders)")
                        detailItem("Seeding", task.seeder ? "Yes" : "No")
                    }
                }

                if let err = task.errorMessage, !err.isEmpty {
                    Divider().opacity(0.2)
                    detailSection("Error") {
                        Text(err)
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(nsColor: NSColor(white: 0.16, alpha: 1)))
        .preferredColorScheme(.dark)
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            content()
        }
    }

    private func detailItem(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .textSelection(.enabled)
        }
    }

    private var statusText: String {
        switch task.status {
        case .active: return "Downloading"
        case .waiting: return "Waiting"
        case .paused: return "Paused"
        case .complete: return "Complete"
        case .error: return "Error"
        case .removed: return "Removed"
        }
    }

    private func fileIcon(_ ext: String) -> String {
        switch ext {
        case "mp4", "mkv", "avi", "mov", "wmv", "flv", "ts": return "film"
        case "mp3", "flac", "aac", "wav", "ogg": return "music.note"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp", "bmp": return "photo"
        case "pdf": return "doc.text"
        case "torrent": return "arrow.down.circle"
        default: return "doc"
        }
    }
}
