import SwiftUI
import UIKit

enum Theme {
    /// Editorial sport palette: warm paper, ink, electric cobalt and a single
    /// acid-lime signal. The goal is a printed training journal, not a neon
    /// dashboard: flat paper surfaces, thin ink rules and one loud accent.
    static let background = adaptive(
        dark: UIColor(red: 0.050, green: 0.053, blue: 0.043, alpha: 1),
        light: UIColor(red: 0.957, green: 0.941, blue: 0.902, alpha: 1)
    )
    static let cardSurface = adaptive(
        dark: UIColor(red: 0.094, green: 0.098, blue: 0.078, alpha: 1),
        light: UIColor(red: 1.000, green: 0.992, blue: 0.965, alpha: 1)
    )
    static let chrome = adaptive(
        dark: UIColor(red: 0.050, green: 0.053, blue: 0.043, alpha: 0.92),
        light: UIColor(red: 0.957, green: 0.941, blue: 0.902, alpha: 0.92)
    )
    static let surface = adaptive(
        dark: UIColor(white: 1, alpha: 0.055),
        light: UIColor(white: 0, alpha: 0.040)
    )
    static let surfaceStrong = adaptive(
        dark: UIColor(white: 1, alpha: 0.10),
        light: UIColor(white: 0, alpha: 0.075)
    )
    static let stroke = adaptive(
        dark: UIColor(white: 1, alpha: 0.15),
        light: UIColor(white: 0, alpha: 0.13)
    )
    static let primaryText = adaptive(
        dark: UIColor(red: 0.972, green: 0.957, blue: 0.914, alpha: 1),
        light: UIColor(red: 0.070, green: 0.075, blue: 0.055, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: UIColor(red: 0.730, green: 0.715, blue: 0.660, alpha: 1),
        light: UIColor(red: 0.350, green: 0.355, blue: 0.305, alpha: 1)
    )
    static let tertiaryText = adaptive(
        dark: UIColor(red: 0.510, green: 0.500, blue: 0.455, alpha: 1),
        light: UIColor(red: 0.505, green: 0.510, blue: 0.455, alpha: 1)
    )
    /// Electric cobalt: the single saturated brand color.
    static let accent = adaptive(
        dark: UIColor(red: 0.570, green: 0.630, blue: 1.000, alpha: 1),
        light: UIColor(red: 0.180, green: 0.290, blue: 1.000, alpha: 1)
    )
    static let accentDeep = adaptive(
        dark: UIColor(red: 0.390, green: 0.470, blue: 1.000, alpha: 1),
        light: UIColor(red: 0.080, green: 0.150, blue: 0.790, alpha: 1)
    )
    /// Acid lime: used for recommendation badges, selected states and one
    /// editorial highlight per screen.
    static let accentSecondary = adaptive(
        dark: UIColor(red: 0.840, green: 1.000, blue: 0.360, alpha: 1),
        light: UIColor(red: 0.370, green: 0.480, blue: 0.000, alpha: 1)
    )
    /// Signal coral: safety, intensity and “look here” moments.
    static let accentTertiary = adaptive(
        dark: UIColor(red: 1.000, green: 0.540, blue: 0.440, alpha: 1),
        light: UIColor(red: 0.770, green: 0.230, blue: 0.120, alpha: 1)
    )
    static let accentWarm = adaptive(
        dark: UIColor(red: 0.960, green: 0.720, blue: 0.350, alpha: 1),
        light: UIColor(red: 0.600, green: 0.360, blue: 0.000, alpha: 1)
    )
    static let onAccent = adaptive(
        dark: UIColor(red: 0.050, green: 0.053, blue: 0.043, alpha: 1),
        light: UIColor(white: 1, alpha: 1)
    )
    static let danger = adaptive(
        dark: UIColor(red: 1.000, green: 0.400, blue: 0.480, alpha: 1),
        light: UIColor(red: 0.850, green: 0.180, blue: 0.270, alpha: 1)
    )
    static let warning = adaptive(
        dark: UIColor(red: 1.000, green: 0.700, blue: 0.330, alpha: 1),
        light: UIColor(red: 0.720, green: 0.380, blue: 0.000, alpha: 1)
    )
    static let blue = adaptive(
        dark: UIColor(red: 0.570, green: 0.630, blue: 1.000, alpha: 1),
        light: UIColor(red: 0.180, green: 0.290, blue: 1.000, alpha: 1)
    )
    static let shadow = adaptive(
        dark: UIColor(white: 0, alpha: 0.45),
        light: UIColor(white: 0, alpha: 0.14)
    )
    static let shadowSoft = adaptive(
        dark: UIColor(white: 0, alpha: 0.22),
        light: UIColor(white: 0, alpha: 0.06)
    )
    static let cardEdge = adaptive(
        dark: UIColor(white: 1, alpha: 0.18),
        light: UIColor(white: 0, alpha: 0.12)
    )

    // Semantic aliases for the new visual language.
    static let paper = cardSurface
    static let ink = primaryText
    static let cobalt = accent
    static let lime = accentSecondary
    static let coral = accentTertiary

    /// Reusable accent ramps for buttons, section markers and highlights.
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let buttonGradient = LinearGradient(
        colors: [accent, accent],
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.button)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.cobalt)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
            }
            .shadow(
                color: Theme.ink.opacity(configuration.isPressed ? 0.04 : 0.16),
                radius: 0,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.impact(.light) }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppType.buttonSecondary)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.75), lineWidth: 1.2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.ink.opacity(configuration.isPressed ? 0.06 : 0))
            }
            .opacity(configuration.isPressed ? 0.92 : 1)
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
            .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.lime : Theme.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Theme.ink.opacity(0.18) : Theme.stroke, lineWidth: 1)
            }
            .animation(Motion.quick, value: selected)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Rectangle()
                    .fill(Theme.lime)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(45))
                Text(title)
                    .font(AppType.headline)
                    .tracking(-0.2)
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
                .fill(tint.opacity(0.14))

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.16), lineWidth: 1)

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.ink)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(Theme.lime)
                .frame(width: size * 0.13, height: size * 0.13)
                .offset(x: size * 0.04, y: -size * 0.04)
        }
        .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.lime)
                    .frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            }

            Text(title)
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            Text(message)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
