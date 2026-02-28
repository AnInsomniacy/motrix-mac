import Foundation

struct ThunderLink {
    static func decode(_ url: String) -> String {
        guard url.lowercased().hasPrefix("thunder://") else { return url }
        let encoded = String(url.dropFirst("thunder://".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: encoded),
              let decoded = String(data: data, encoding: .utf8),
              decoded.count > 4 else { return url }
        return String(decoded.dropFirst(2).dropLast(2))
    }
}
