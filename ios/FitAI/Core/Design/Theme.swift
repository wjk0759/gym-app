import SwiftUI
import UIKit

enum Theme {
    /// Neutral graphite base with a muted sage-mint accent.
    /// Light mode stays warm and paper-like so the frosted surfaces read clearly.
    static let background = adaptive(
        dark: UIColor(red: 0.030, green: 0.034, blue: 0.040, alpha: 1),
        light: UIColor(red: 0.953, green: 0.957, blue: 0.949, alpha: 1)
    )
    static let cardSurface = adaptive(
        dark: UIColor(red: 0.062, green: 0.068, blue: 0.078, alpha: 1),
        light: UIColor(red: 0.984, green: 0.986, blue: 0.980, alpha: 1)
    )
    static let chrome = adaptive(
        dark: UIColor(red: 0.024, green: 0.032, blue: 0.046, alpha: 0.86),
        light: UIColor(red: 0.970, green: 0.976, blue: 0.965, alpha: 0.90)
    )
    static let surface = adaptive(
        dark: UIColor(white: 1, alpha: 0.06),
        light: UIColor(white: 0, alpha: 0.04)
    )
    static let surfaceStrong = adaptive(
        dark: UIColor(white: 1, alpha: 0.105),
        light: UIColor(white: 0, alpha: 0.07)
    )
    static let stroke = adaptive(
        dark: UIColor(white: 1, alpha: 0.105),
        light: UIColor(white: 0, alpha: 0.085)
    )
    static let primaryText = adaptive(
        dark: UIColor(white: 0.97, alpha: 1),
        light: UIColor(red: 0.055, green: 0.070, blue: 0.060, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.68),
        light: UIColor(white: 0, alpha: 0.60)
    )
    static let tertiaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.48),
        light: UIColor(white: 0, alpha: 0.47)
    )
    static let accent = adaptive(
        dark: UIColor(red: 0.54, green: 0.86, blue: 0.70, alpha: 1),
        light: UIColor(red: 0.090, green: 0.360, blue: 0.250, alpha: 1)
    )
    static let accentDeep = adaptive(
        dark: UIColor(red: 0.26, green: 0.60, blue: 0.46, alpha: 1),
        light: UIColor(red: 0.050, green: 0.250, blue: 0.170, alpha: 1)
    )
    static let accentSecondary = adaptive(
        dark: UIColor(red: 0.42, green: 0.70, blue: 0.78, alpha: 1),
        light: UIColor(red: 0.160, green: 0.400, blue: 0.470, alpha: 1)
    )
    static let accentTertiary = adaptive(
        dark: UIColor(red: 0.64, green: 0.60, blue: 0.80, alpha: 1),
        light: UIColor(red: 0.360, green: 0.300, blue: 0.520, alpha: 1)
    )
    static let accentWarm = adaptive(
        dark: UIColor(red: 0.88, green: 0.70, blue: 0.46, alpha: 1),
        light: UIColor(red: 0.620, green: 0.400, blue: 0.120, alpha: 1)
    )
    static let onAccent = adaptive(
        dark: UIColor(red: 0.020, green: 0.070, blue: 0.045, alpha: 0.96),
        light: UIColor(white: 1, alpha: 0.97)
    )
    static let danger = adaptive(
        dark: UIColor(red: 1.0, green: 0.36, blue: 0.42, alpha: 1),
        light: UIColor(red: 0.760, green: 0.130, blue: 0.200, alpha: 1)
    )
    static let warning = adaptive(
        dark: UIColor(red: 1.0, green: 0.68, blue: 0.30, alpha: 1),
        light: UIColor(red: 0.640, green: 0.380, blue: 0.020, alpha: 1)
    )
    static let blue = adaptive(
        dark: UIColor(red: 0.36, green: 0.78, blue: 1.0, alpha: 1),
        light: UIColor(red: 0.120, green: 0.400, blue: 0.820, alpha: 1)
    )
    static let shadow = adaptive(
        dark: UIColor(white: 0, alpha: 0.35),
        light: UIColor(white: 0, alpha: 0.10)
    )
    static let shadowSoft = adaptive(
        dark: UIColor(white: 0, alpha: 0.16),
        light: UIColor(white: 0, alpha: 0.05)
    )
    static let cardEdge = adaptive(
        dark: UIColor(white: 1, alpha: 0.16),
        light: UIColor(white: 0, alpha: 0.08)
    )

    /// Reusable accent ramps for buttons, section markers and highlights.
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let buttonGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 固定深色图片/视频上的文字，不跟随系统浅色变化。
    static let onMedia = Color.white

    private static func adaptive(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct AppBackground: View {
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Static only: weather animation used to be inherited by sheets and
        // navigation destinations, creating multiple full-screen draw layers.
        AmbientBackdrop()
            .animation(
                Motion.resolved(.easeInOut(duration: 1.1), reduceMotion: reduceMotion),
                value: atmosphere
            )
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
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.button)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Theme.buttonGradient)
                    .opacity(colorScheme == .dark ? 0.88 : 0.94)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.14 : 0.24),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.26 : 0.12),
                radius: 12,
                y: 6
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.impact(.light) }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.buttonSecondary)
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surfaceStrong.opacity(colorScheme == .dark ? 0.55 : 0.45))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.primaryText.opacity(configuration.isPressed ? 0.04 : 0))
            }
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

struct TagChip: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(AppType.chip)
            .foregroundStyle(selected ? Theme.accent : Theme.secondaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)

                Capsule(style: .continuous)
                    .fill(
                        selected
                            ? Theme.accent.opacity(0.16)
                            : Theme.surface
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        selected ? Theme.accent.opacity(0.36) : Theme.stroke,
                        lineWidth: 0.8
                    )
            }
            .animation(Motion.quick, value: selected)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Capsule(style: .continuous)
                    .fill(Theme.accent.opacity(0.82))
                    .frame(width: 14, height: 2)
                Text(title)
                    .font(AppType.headline)
                    .tracking(0.1)
                    .foregroundStyle(Theme.primaryText)
            }
            if let subtitle {
                Text(subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 轻量几何图形替代插画：只用系统符号和一层渐变，避免大图解码和“卡通感”。
struct HeroGlyph: View {
    let symbol: String
    var size: CGFloat = 100
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(tint.opacity(0.10))

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.opacity(0.94))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                Circle()
                    .strokeBorder(Theme.stroke, lineWidth: 0.8)
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Text(title)
                .font(AppType.title)
                .foregroundStyle(Theme.primaryText)
            Text(message)
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 30)
    }
}
