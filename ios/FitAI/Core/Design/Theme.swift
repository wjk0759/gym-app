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

    /// 品牌亮绿。用于大图标、媒体上的装饰和深色模式强调；
    /// 系统背景上的文字/图标请用 `accentText`，填充控件请用 `accentFill`。
    static let accent = Color.accentColor
    static let onAccent = Color.white

    /// 填充型主按钮使用更深的绿色，保证白字对比度 ≥ 4.5:1。
    /// 品牌亮绿 #5CDB8C 继续用于图标、选中态和深色模式强调色。
    static let accentFill = Color(red: 0.08, green: 0.45, blue: 0.28)
    static let onAccentFill = Color.white

    /// 链接、复选框和图标文字：浅色模式深绿，深色模式亮绿。
    static let accentText = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.36, green: 0.86, blue: 0.55, alpha: 1)
            }
            return UIColor(red: 0.08, green: 0.45, blue: 0.28, alpha: 1)
        }
    )

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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.button)
            .foregroundStyle(Theme.onAccentFill)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Theme.accentFill,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

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
            .opacity(isEnabled ? (configuration.isPressed ? 0.70 : 1) : 0.45)
    }
}

struct TagChip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(AppType.chip)
            .foregroundStyle(selected ? Theme.onAccentFill : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selected ? Theme.accentFill : Color(.tertiarySystemFill),
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
    var tint: Color = Theme.accentText

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
