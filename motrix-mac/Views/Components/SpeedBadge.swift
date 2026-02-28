import SwiftUI

struct SpeedBadge: View {
    let speed: Int64
    let direction: Direction

    enum Direction {
        case download, upload
        var icon: String {
            switch self {
            case .download: return "arrow.down"
            case .upload: return "arrow.up"
            }
        }
        var color: Color {
            switch self {
            case .download: return .blue
            case .upload: return .green
            }
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: direction.icon)
                .font(.system(size: 9, weight: .bold))
            Text(ByteFormatter.speed(speed))
                .font(.system(size: 11, design: .monospaced))
        }
        .foregroundStyle(speed > 0 ? direction.color : .secondary)
    }
}
