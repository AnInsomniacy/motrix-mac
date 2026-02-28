import Foundation
import os

final class TrackerService {
    private let logger = Logger(subsystem: "app.motrix", category: "TrackerService")

    static let defaultSources = [
        "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt",
        "https://cdn.jsdelivr.net/gh/ngosang/trackerslist/trackers_best.txt"
    ]

    func fetchTrackers(from sources: [String] = defaultSources) async -> String {
        var allTrackers: Set<String> = []

        for source in sources {
            guard let url = URL(string: source) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let text = String(data: data, encoding: .utf8) {
                    let trackers = text.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    allTrackers.formUnion(trackers)
                }
            } catch {
                logger.warning("failed to fetch trackers from \(source): \(error.localizedDescription)")
            }
        }

        let result = allTrackers.joined(separator: ",")
        let maxLen = 6144
        if result.count <= maxLen { return result }
        let sub = String(result.prefix(maxLen))
        if let idx = sub.lastIndex(of: ",") {
            return String(sub[sub.startIndex..<idx])
        }
        return sub
    }
}
