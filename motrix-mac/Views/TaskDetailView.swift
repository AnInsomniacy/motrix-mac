import SwiftUI

struct TaskDetailView: View {
    let task: DownloadTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    nameSection
                    Divider().opacity(0.2)
                    statusSection
                    Divider().opacity(0.2)
                    progressSection
                    Divider().opacity(0.2)
                    sizeSection
                    Divider().opacity(0.2)
                    speedSection
                    Divider().opacity(0.2)
                    pathSection
                    btSection
                    filesSection
                    errorSection
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .frame(width: 560)
        .frame(maxHeight: 600)
        .background(Color(nsColor: NSColor(white: 0.16, alpha: 1)))
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerBar: some View {
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
    }

    private var nameSection: some View {
        detailSection("Name") {
            Text(task.name)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        }
    }

    private var statusSection: some View {
        HStack(spacing: 20) {
            detailItem("Status", statusText, color: statusColor)
            detailItem("GID", task.gid)
            if let code = task.errorCode, !code.isEmpty {
                detailItem("Error Code", code, color: .red)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PROGRESS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(String(format: "%.1f%%", task.progress * 100))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(statusColor)
                        .frame(width: max(0, geo.size.width * task.progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var sizeSection: some View {
        HStack(spacing: 20) {
            detailItem("Total", ByteFormatter.format(task.totalLength))
            detailItem("Downloaded", ByteFormatter.format(task.completedLength))
            if task.uploadLength > 0 {
                detailItem("Uploaded", ByteFormatter.format(task.uploadLength))
            }
        }
    }

    private var speedSection: some View {
        HStack(spacing: 20) {
            detailItem("↓ Speed", ByteFormatter.speed(task.downloadSpeed),
                       color: task.downloadSpeed > 0 ? .blue : .white.opacity(0.5))
            detailItem("↑ Speed", ByteFormatter.speed(task.uploadSpeed),
                       color: task.uploadSpeed > 0 ? .green : .white.opacity(0.5))
            detailItem("Connections", "\(task.connections)")
            if !task.remaining.isEmpty {
                detailItem("ETA", task.remaining)
            }
        }
    }

    private var pathSection: some View {
        detailSection("Save Path") {
            Text(task.dir)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var btSection: some View {
        if task.isBT {
            Divider().opacity(0.2)
            detailSection("BitTorrent") {
                btContent
            }
        }
    }

    private var btContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            btHashRow
            HStack(spacing: 20) {
                detailItem("Seeders", "\(task.numSeeders)")
                detailItem("Seeding", task.seeder ? "Yes" : "No",
                           color: task.seeder ? .mint : .white.opacity(0.5))
                if task.isMagnet {
                    detailItem("Type", "Magnet")
                }
            }
            btTrackerList
        }
    }

    @ViewBuilder
    private var btHashRow: some View {
        if let hash = task.infoHash {
            VStack(alignment: .leading, spacing: 2) {
                Text("INFO HASH")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Text(hash)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var btTrackerList: some View {
        if let bt = task.bittorrent, !bt.announceList.isEmpty {
            Divider().opacity(0.15)
            Text("TRACKERS (\(bt.announceList.count))")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(bt.announceList.prefix(8).enumerated()), id: \.offset) { _, tracker in
                    Text(tracker)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if bt.announceList.count > 8 {
                    Text("… and \(bt.announceList.count - 8) more")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        if !task.files.isEmpty {
            Divider().opacity(0.2)
            detailSection("Files (\(task.files.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.files) { file in
                        fileRow(file)
                    }
                }
            }
        }
    }

    private func fileRow(_ file: TaskFile) -> some View {
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
            if file.length > 0 {
                Text("\(fileProgress(file))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(ByteFormatter.format(file.length))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let err = task.errorMessage, !err.isEmpty {
            Divider().opacity(0.2)
            detailSection("Error") {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.8))
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            content()
        }
    }

    private func detailItem(_ title: String, _ value: String, color: Color = .white.opacity(0.75)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(color)
                .textSelection(.enabled)
        }
    }

    private var statusText: String {
        switch task.status {
        case .active: return task.isSeeding ? "Seeding" : "Downloading"
        case .waiting: return "Waiting"
        case .paused: return "Paused"
        case .complete: return "Complete"
        case .error: return "Error"
        case .removed: return "Removed"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .active: return task.isSeeding ? .mint : .blue
        case .waiting, .paused: return .orange
        case .complete: return .green
        case .error: return .red
        case .removed: return .gray
        }
    }

    private func fileProgress(_ file: TaskFile) -> String {
        guard file.length > 0 else { return "0" }
        let pct = Double(file.completedLength) / Double(file.length) * 100
        return String(format: "%.0f", pct)
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
