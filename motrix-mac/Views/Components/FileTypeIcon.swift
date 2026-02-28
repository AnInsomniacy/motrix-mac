import SwiftUI

struct FileTypeIcon: View {
    let extension_: String

    private var category: FileCategory {
        FileCategory.from(extension_)
    }

    var body: some View {
        Image(systemName: category.systemImage)
            .font(.system(size: 16))
            .foregroundStyle(category.color)
            .frame(width: 28, height: 28)
    }
}

private enum FileCategory {
    case video, audio, image, document, archive, application, other

    var systemImage: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .document: return "doc"
        case .archive: return "archivebox"
        case .application: return "app"
        case .other: return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .video: return .purple
        case .audio: return .pink
        case .image: return .orange
        case .document: return .blue
        case .archive: return .yellow
        case .application: return .green
        case .other: return .secondary
        }
    }

    static func from(_ ext: String) -> FileCategory {
        let e = ext.lowercased()
        let videoExts: Set = ["mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "ts", "m4v", "rmvb"]
        let audioExts: Set = ["mp3", "flac", "wav", "aac", "ogg", "m4a", "wma", "ape"]
        let imageExts: Set = ["jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "ico", "tiff"]
        let docExts: Set = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "epub"]
        let archiveExts: Set = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso"]
        let appExts: Set = ["exe", "msi", "pkg", "deb", "rpm", "app", "apk"]

        if videoExts.contains(e) { return .video }
        if audioExts.contains(e) { return .audio }
        if imageExts.contains(e) { return .image }
        if docExts.contains(e) { return .document }
        if archiveExts.contains(e) { return .archive }
        if appExts.contains(e) { return .application }
        return .other
    }
}
