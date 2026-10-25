import SwiftUI

enum Theme {
    static let background = Color(red: 0.051, green: 0.063, blue: 0.086)
    static let surface = Color.white.opacity(0.06)
    static let surfaceStrong = Color.white.opacity(0.11)
    static let stroke = Color.white.opacity(0.09)
    static let accent = Color(red: 0.36, green: 0.86, blue: 0.55)
    static let secondaryText = Color.white.opacity(0.66)
    static let tertiaryText = Color.white.opacity(0.50)
    static let danger = Color(red: 0.95, green: 0.42, blue: 0.38)
    static let warning = Color(red: 0.98, green: 0.72, blue: 0.30)
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
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
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent.opacity(configuration.isPressed ? 0.78 : 1))
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent.opacity(configuration.isPressed ? 0.16 : 0.10))
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
