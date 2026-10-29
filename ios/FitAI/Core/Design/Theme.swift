import SwiftUI
import UIKit

enum Theme {
    /// Deep, slightly cool dark base with vibrant mint, cyan and violet accents.
    /// Light mode stays warm and paper-like so the glass surfaces read clearly.
    static let background = adaptive(
        dark: UIColor(red: 0.020, green: 0.026, blue: 0.038, alpha: 1),
        light: UIColor(red: 0.945, green: 0.949, blue: 0.936, alpha: 1)
    )
    static let cardSurface = adaptive(
        dark: UIColor(red: 0.055, green: 0.067, blue: 0.085, alpha: 1),
        light: UIColor(red: 0.998, green: 0.999, blue: 0.996, alpha: 1)
    )
    static let chrome = adaptive(
        dark: UIColor(red: 0.024, green: 0.032, blue: 0.046, alpha: 0.86),
        light: UIColor(red: 0.970, green: 0.976, blue: 0.965, alpha: 0.90)
    )
    static let surface = adaptive(
        dark: UIColor(white: 1, alpha: 0.06),
        light: UIColor(white: 0, alpha: 0.045)
    )
    static let surfaceStrong = adaptive(
        dark: UIColor(white: 1, alpha: 0.105),
        light: UIColor(white: 0, alpha: 0.075)
    )
    static let stroke = adaptive(
        dark: UIColor(white: 1, alpha: 0.105),
        light: UIColor(white: 0, alpha: 0.13)
    )
    static let primaryText = adaptive(
        dark: UIColor(white: 0.97, alpha: 1),
        light: UIColor(red: 0.055, green: 0.070, blue: 0.060, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.68),
        light: UIColor(white: 0, alpha: 0.62)
    )
    static let tertiaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.48),
        light: UIColor(white: 0, alpha: 0.50)
    )
    static let accent = adaptive(
        dark: UIColor(red: 0.42, green: 0.96, blue: 0.58, alpha: 1),
        light: UIColor(red: 0.020, green: 0.440, blue: 0.210, alpha: 1)
    )
    static let accentDeep = adaptive(
        dark: UIColor(red: 0.10, green: 0.62, blue: 0.38, alpha: 1),
        light: UIColor(red: 0.010, green: 0.310, blue: 0.140, alpha: 1)
    )
    static let accentSecondary = adaptive(
        dark: UIColor(red: 0.36, green: 0.84, blue: 1.0, alpha: 1),
        light: UIColor(red: 0.030, green: 0.360, blue: 0.540, alpha: 1)
    )
    static let accentTertiary = adaptive(
        dark: UIColor(red: 0.72, green: 0.62, blue: 1.0, alpha: 1),
        light: UIColor(red: 0.320, green: 0.240, blue: 0.580, alpha: 1)
    )
    static let accentWarm = adaptive(
        dark: UIColor(red: 1.0, green: 0.72, blue: 0.38, alpha: 1),
        light: UIColor(red: 0.620, green: 0.380, blue: 0.060, alpha: 1)
    )
    static let onAccent = adaptive(
        dark: UIColor(red: 0.008, green: 0.025, blue: 0.012, alpha: 0.95),
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
        light: UIColor(white: 0, alpha: 0.12)
    )
    static let shadowSoft = adaptive(
        dark: UIColor(white: 0, alpha: 0.16),
        light: UIColor(white: 0, alpha: 0.06)
    )
    static let cardEdge = adaptive(
        dark: UIColor(white: 1, alpha: 0.16),
        light: UIColor(white: 0, alpha: 0.12)
    )

    /// Reusable accent ramps for buttons, section markers and highlights.
    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let buttonGradient = LinearGradient(
        colors: [accent, accentDeep, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
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
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Theme.buttonGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.46), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: Theme.accent.opacity(0.20), radius: 14, y: 7)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
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
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                SoftSurface(
                    cornerRadius: 16,
                    tint: Theme.surfaceStrong
                )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.primaryText.opacity(configuration.isPressed ? 0.05 : 0))
            )
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background {
                SoftSurface(
                    cornerRadius: 999,
                    tint: selected ? Theme.accent : Theme.surfaceStrong,
                    stroke: selected ? Theme.accent.opacity(0.72) : Theme.stroke
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
                    .fill(Theme.accentGradient)
                    .frame(width: 18, height: 3)
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
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.28),
                            tint.opacity(0.06),
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.34), tint.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint.opacity(0.96))
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
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 64, height: 64)
                Circle()
                    .stroke(Theme.accent.opacity(0.18), lineWidth: 1)
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
