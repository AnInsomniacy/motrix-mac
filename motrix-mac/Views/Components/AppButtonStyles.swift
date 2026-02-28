import SwiftUI

struct MotrixButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor(configuration: configuration))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(backgroundColor(configuration: configuration))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor(configuration: configuration), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if prominent {
            return configuration.isPressed ? Color.blue.opacity(0.55) : Color.blue.opacity(0.45)
        }
        return configuration.isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.08)
    }

    private func borderColor(configuration: Configuration) -> Color {
        if prominent {
            return Color.blue.opacity(configuration.isPressed ? 0.65 : 0.55)
        }
        return Color.white.opacity(configuration.isPressed ? 0.2 : 0.14)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        if prominent {
            return Color.white.opacity(configuration.isPressed ? 0.92 : 1.0)
        }
        return Color.white.opacity(configuration.isPressed ? 0.8 : 0.9)
    }
}

struct MotrixIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.85 : 0.75))
            .frame(width: 30, height: 30)
            .background(configuration.isPressed ? Color.white.opacity(0.12) : Color.white.opacity(0.08))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(configuration.isPressed ? 0.2 : 0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
