import Foundation

struct TimeRemainingFormatter {
    static func format(totalLength: Int64, completedLength: Int64, downloadSpeed: Int64) -> String {
        guard downloadSpeed > 0 else { return "" }
        let remaining = totalLength - completedLength
        let seconds = Int(remaining / downloadSpeed)
        return format(seconds: seconds)
    }

    static func format(seconds: Int) -> String {
        if seconds <= 0 { return "" }
        if seconds > 86400 { return "> 1 day" }

        var s = seconds
        var parts: [String] = []

        if s >= 3600 {
            parts.append("\(s / 3600)h")
            s %= 3600
        }
        if s >= 60 {
            parts.append("\(s / 60)m")
            s %= 60
        }
        parts.append("\(s)s")

        return parts.joined(separator: " ")
    }
}
