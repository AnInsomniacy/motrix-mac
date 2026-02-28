import SwiftUI
import UniformTypeIdentifiers

struct AddTaskView: View {
    @Environment(AppState.self) private var state
    let downloadService: DownloadService

    @State private var urlText = ""
    @State private var downloadDir = ConfigService.shared.downloadDir
    @State private var mode: AddMode = .url
    @State private var torrentData: Data?
    @State private var torrentFileName = ""
    @State private var torrentFiles: [TorrentContentFile] = []

    enum AddMode: String, CaseIterable {
        case url = "URL"
        case torrent = "Torrent"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add New Task")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Add URLs or torrent files without leaving the main workspace")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }

                VStack(spacing: 16) {
                    Picker("", selection: $mode) {
                        ForEach(AddMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    if mode == .url {
                        urlSection
                    } else {
                        torrentSection
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(downloadDir)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Browse") { pickDirectory() }
                            .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack {
                        Spacer()
                        Button("Cancel") { close() }
                            .keyboardShortcut(.cancelAction)
                        Button("Download") { submit() }
                            .keyboardShortcut(.defaultAction)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(!canSubmit)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .onAppear {
            if !state.addTaskURL.isEmpty {
                urlText = state.addTaskURL
                state.addTaskURL = ""
            }
            if let data = state.addTaskTorrentData {
                loadTorrent(data: data, fileName: state.addTaskTorrentName)
                state.addTaskTorrentData = nil
                state.addTaskTorrentName = ""
            }
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Enter URLs (one per line)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextEditor(text: $urlText)
                .font(.system(size: 13, design: .monospaced))
                .frame(height: 170)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.1)))
        }
    }

    private var torrentSection: some View {
        VStack(spacing: 12) {
            if let _ = torrentData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.blue)
                        Text(torrentFileName)
                            .font(.system(size: 13))
                        Spacer()
                        Button("Clear") {
                            torrentData = nil
                            torrentFileName = ""
                            torrentFiles = []
                        }
                        .controlSize(.small)
                    }
                    HStack(spacing: 8) {
                        Text("\(selectedFileCount)/\(torrentFiles.count) files")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(ByteFormatter.format(selectedFileSize))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if !torrentFiles.isEmpty {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach($torrentFiles) { $file in
                                    Toggle(isOn: $file.selected) {
                                        HStack {
                                            Text(file.name)
                                                .font(.system(size: 12))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Text(ByteFormatter.format(file.length))
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    } else {
                        Text("Cannot parse file list, this torrent will be added as full download")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(nsColor: NSColor(white: 0.15, alpha: 1)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button(action: pickTorrent) {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Select .torrent file")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color(nsColor: NSColor(white: 0.12, alpha: 1)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canSubmit: Bool {
        if mode == .url { return !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if torrentData == nil { return false }
        return torrentFiles.isEmpty || selectedFileCount > 0
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            downloadDir = url.path
        }
    }

    private func pickTorrent() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent")!]
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                loadTorrent(data: data, fileName: url.lastPathComponent)
            }
        }
    }

    private func submit() {
        Task {
            let options = ["dir": downloadDir]
            if mode == .url {
                let uris = urlText.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { ThunderLink.decode($0) }
                for uri in uris {
                    do {
                        try await downloadService.addUri(uris: [uri], options: options)
                    } catch {
                        await MainActor.run {
                            state.presentError("Add URL failed: \(error.localizedDescription)")
                        }
                        return
                    }
                }
            } else if let data = torrentData {
                var torrentOptions = options
                let selectedIndexes = torrentFiles.filter { $0.selected }.map { String($0.index) }.joined(separator: ",")
                if !selectedIndexes.isEmpty {
                    torrentOptions["select-file"] = selectedIndexes
                }
                do {
                    try await downloadService.addTorrent(data: data, options: torrentOptions)
                } catch {
                    await MainActor.run {
                        state.presentError("Add torrent failed: \(error.localizedDescription)")
                    }
                    return
                }
            }
            close()
        }
    }

    private func close() {
        state.currentSection = .tasks
    }

    private var selectedFileCount: Int {
        torrentFiles.filter { $0.selected }.count
    }

    private var selectedFileSize: Int64 {
        torrentFiles.filter { $0.selected }.reduce(0) { $0 + $1.length }
    }

    private func loadTorrent(data: Data, fileName: String) {
        torrentData = data
        torrentFileName = fileName
        mode = .torrent
        torrentFiles = TorrentParser.parseFiles(data: data).enumerated().map { offset, file in
            TorrentContentFile(index: offset + 1, name: file.name, length: file.length, selected: true)
        }
    }
}

struct TorrentContentFile: Identifiable {
    let index: Int
    let name: String
    let length: Int64
    var selected: Bool
    var id: Int { index }
}

enum TorrentParser {
    static func parseFiles(data: Data) -> [(name: String, length: Int64)] {
        guard let root = BencodeDecoder(data: data).decode(),
              case .dictionary(let rootDict) = root,
              case .dictionary(let infoDict)? = rootDict["info"] else {
            return []
        }
        if case .list(let files)? = infoDict["files"] {
            return files.enumerated().compactMap { offset, item in
                guard case .dictionary(let fileDict) = item else { return nil }
                let length: Int64
                if case .integer(let value)? = fileDict["length"] {
                    length = value
                } else {
                    length = 0
                }
                let path: String
                if case .list(let segments)? = fileDict["path"] {
                    let names = segments.compactMap { part -> String? in
                        guard case .bytes(let data) = part else { return nil }
                        return String(data: data, encoding: .utf8)
                    }
                    path = names.isEmpty ? "file-\(offset + 1)" : names.joined(separator: "/")
                } else {
                    path = "file-\(offset + 1)"
                }
                return (path, length)
            }
        }
        let length: Int64
        if case .integer(let value)? = infoDict["length"] {
            length = value
        } else {
            length = 0
        }
        let name: String
        if case .bytes(let data)? = infoDict["name"], let value = String(data: data, encoding: .utf8), !value.isEmpty {
            name = value
        } else {
            name = "content"
        }
        return [(name, length)]
    }
}

enum BencodeValue {
    case integer(Int64)
    case bytes(Data)
    case list([BencodeValue])
    case dictionary([String: BencodeValue])
}

struct BencodeDecoder {
    let data: Data
    private var bytes: [UInt8] { Array(data) }

    func decode() -> BencodeValue? {
        var index = 0
        return parseValue(bytes, &index)
    }

    private func parseValue(_ bytes: [UInt8], _ index: inout Int) -> BencodeValue? {
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        if byte == UInt8(ascii: "i") {
            index += 1
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") { index += 1 }
            guard index < bytes.count else { return nil }
            let numberData = Data(bytes[start..<index])
            index += 1
            guard let numberString = String(data: numberData, encoding: .utf8), let value = Int64(numberString) else { return nil }
            return .integer(value)
        }
        if byte == UInt8(ascii: "l") {
            index += 1
            var result: [BencodeValue] = []
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
                guard let item = parseValue(bytes, &index) else { return nil }
                result.append(item)
            }
            guard index < bytes.count else { return nil }
            index += 1
            return .list(result)
        }
        if byte == UInt8(ascii: "d") {
            index += 1
            var result: [String: BencodeValue] = [:]
            while index < bytes.count, bytes[index] != UInt8(ascii: "e") {
                guard let keyValue = parseValue(bytes, &index), case .bytes(let keyData) = keyValue,
                      let key = String(data: keyData, encoding: .utf8),
                      let value = parseValue(bytes, &index) else { return nil }
                result[key] = value
            }
            guard index < bytes.count else { return nil }
            index += 1
            return .dictionary(result)
        }
        if byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") {
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: ":") { index += 1 }
            guard index < bytes.count else { return nil }
            let lengthData = Data(bytes[start..<index])
            index += 1
            guard let lengthString = String(data: lengthData, encoding: .utf8), let length = Int(lengthString),
                  index + length <= bytes.count else { return nil }
            let payload = Data(bytes[index..<(index + length)])
            index += length
            return .bytes(payload)
        }
        return nil
    }
}
