import SwiftUI

enum Theme {
    static let background = Color(red: 0.035, green: 0.038, blue: 0.047)
    static let surface = Color.white.opacity(0.055)
    static let surfaceStrong = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.09)
    static let accent = Color(red: 0.188, green: 0.82, blue: 0.345)
    static let accentDeep = Color(red: 0.075, green: 0.64, blue: 0.27)
    static let secondaryText = Color.white.opacity(0.70)
    static let tertiaryText = Color.white.opacity(0.52)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let warning = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let blue = Color(red: 0.35, green: 0.56, blue: 1.0)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.accent.opacity(0.075), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Theme.blue.opacity(0.055), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 560
            )
        }
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.045),
                                Color.white.opacity(0.012)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 0.7)
            )
            .shadow(color: Theme.accent.opacity(0.20), radius: 16, y: 8)
            .opacity(configuration.isPressed ? 0.84 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.82),
                value: configuration.isPressed
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(
                .spring(response: 0.28, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}

struct TagChip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(selected ? Color.black : Theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Theme.accent : Theme.surfaceStrong)
            )
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 28)
    }
}
