import Foundation
import os

final class ProtocolService {
    private let logger = Logger(subsystem: "app.motrix", category: "ProtocolService")

    func parseURL(_ url: URL) -> ParsedProtocol? {
        let str = url.absoluteString.lowercased()

        if str.hasPrefix("magnet:") || str.hasPrefix("http:") || str.hasPrefix("https:") ||
           str.hasPrefix("ftp:") || str.hasPrefix("thunder:") {
            var uri = url.absoluteString
            if str.hasPrefix("thunder:") {
                uri = ThunderLink.decode(uri)
            }
            return .download(uri)
        }

        if str.hasPrefix("mo:") || str.hasPrefix("motrix:") {
            return .command(url)
        }

        return nil
    }

    func isSupportedScheme(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.hasPrefix("http:") || lower.hasPrefix("https:") ||
               lower.hasPrefix("ftp:") || lower.hasPrefix("magnet:") ||
               lower.hasPrefix("thunder:") || lower.hasPrefix("mo:") ||
               lower.hasPrefix("motrix:")
    }

    func isTorrentFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "torrent"
    }
}

enum ParsedProtocol {
    case download(String)
    case command(URL)
}
