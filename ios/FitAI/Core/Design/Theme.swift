import SwiftUI
import UIKit

enum Theme {
    // Native semantic colors. These automatically follow light/dark mode,
    // increased contrast and the system's Liquid Glass materials.
    static let background = Color(.systemGroupedBackground)
    static let cardSurface = Color(.secondarySystemGroupedBackground)
    static let chrome = Color(.systemBackground)
    static let surface = Color(.tertiarySystemFill)
    static let surfaceStrong = Color(.secondarySystemFill)
    static let stroke = Color(.separator)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    static let accent = Color.accentColor
    static let onAccent = Color.white
    static let danger = Color.red
    static let warning = Color.orange
    static let blue = Color.blue

    static let shadow = Color.black.opacity(0.12)
    static let shadowSoft = Color.black.opacity(0.06)
    static let cardEdge = Color(.separator)

    /// 固定深色图片/视频上的文字，不跟随系统浅色变化。
    static let onMedia = Color.white
}

struct AppBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = AppLayout.cardPadding

    func body(content: Content) -> some View {
        content.glassCard(padding: padding)
    }
}

extension View {
    func card(padding: CGFloat = AppLayout.cardPadding) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Theme.accent,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.buttonSecondary)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Color(.secondarySystemFill),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.70 : 1)
    }
}

struct TagChip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(AppType.chip)
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selected ? Theme.accent : Color(.tertiarySystemFill),
                in: Capsule()
            )
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppType.headline)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Lightweight native symbol badge. No custom illustration or gradient.
struct HeroGlyph: View {
    let symbol: String
    var size: CGFloat = 100
    var tint: Color = Theme.accent

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                tint.opacity(0.12),
                in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity)
    }
}
