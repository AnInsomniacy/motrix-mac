import Foundation

struct MagnetLink {
    static func build(infoHash: String, name: String? = nil, trackers: [String] = []) -> String {
        var parts = ["magnet:?xt=urn:btih:\(infoHash)"]
        if let name = name {
            parts.append("dn=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)")
        }
        for tracker in trackers {
            parts.append("tr=\(tracker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tracker)")
        }
        return parts.joined(separator: "&")
    }

    static func isMagnet(_ url: String) -> Bool {
        url.lowercased().hasPrefix("magnet:")
    }
}
