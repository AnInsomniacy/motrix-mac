import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    private let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    private let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("About Motrix")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("A clean, high-performance download manager powered by aria2")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(spacing: 14) {
                    infoCard(title: "Version", value: appVersion)
                    infoCard(title: "Build", value: buildVersion)
                    infoCard(title: "Engine", value: "aria2")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Highlights")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    featureRow(icon: "bolt.fill", text: "Multi-protocol downloads with parallel connections")
                    featureRow(icon: "link", text: "Magnet, Thunder, HTTP, HTTPS, FTP, and BitTorrent support")
                    featureRow(icon: "speedometer", text: "Live transfer speed, queue controls, and quick actions")
                    featureRow(icon: "slider.horizontal.3", text: "Flexible settings for speed limits and seeding")
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

                HStack(spacing: 10) {
                    Button("GitHub") {
                        openURL(URL(string: "https://github.com/agalwood/Motrix")!)
                    }
                    .buttonStyle(MotrixButtonStyle(prominent: true))
                    Button("aria2") {
                        openURL(URL(string: "https://aria2.github.io/")!)
                    }
                    .buttonStyle(MotrixButtonStyle(prominent: false))
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    }

    private func infoCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
