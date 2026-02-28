import Foundation

struct ByteFormatter {
    static let units = ["B", "KB", "MB", "GB", "TB"]

    static func format(_ bytes: Int64, precision: Int = 1) -> String {
        if bytes == 0 { return "0 KB" }
        let b = Double(bytes)
        let i = Int(floor(log(b) / log(1024)))
        if i == 0 { return "\(bytes) \(units[i])" }
        return String(format: "%.\(precision)f %@", b / pow(1024, Double(i)), units[i])
    }

    static func speed(_ bytesPerSecond: Int64) -> String {
        "\(format(bytesPerSecond))/s"
    }
}
