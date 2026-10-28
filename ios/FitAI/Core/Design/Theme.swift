import SwiftUI
import UIKit

enum Theme {
    /// 系统浅色/深色、时段、天气共用同一套语义色。
    /// 颜色仍保持低饱和，避免变成一张刺眼的白底 App。
    static let background = adaptive(
        dark: UIColor(red: 0.035, green: 0.038, blue: 0.047, alpha: 1),
        light: UIColor(red: 0.953, green: 0.965, blue: 0.941, alpha: 1)
    )
    static let cardSurface = adaptive(
        dark: UIColor(red: 0.082, green: 0.086, blue: 0.096, alpha: 1),
        light: UIColor(red: 0.997, green: 0.999, blue: 0.995, alpha: 1)
    )
    static let chrome = adaptive(
        dark: UIColor(red: 0.050, green: 0.054, blue: 0.063, alpha: 1),
        light: UIColor(red: 0.972, green: 0.980, blue: 0.962, alpha: 1)
    )
    static let surface = adaptive(
        dark: UIColor(white: 1, alpha: 0.055),
        light: UIColor(white: 0, alpha: 0.045)
    )
    static let surfaceStrong = adaptive(
        dark: UIColor(white: 1, alpha: 0.10),
        light: UIColor(white: 0, alpha: 0.075)
    )
    static let stroke = adaptive(
        dark: UIColor(white: 1, alpha: 0.09),
        light: UIColor(white: 0, alpha: 0.09)
    )
    static let primaryText = adaptive(
        dark: UIColor(white: 1, alpha: 1),
        light: UIColor(red: 0.071, green: 0.090, blue: 0.071, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.70),
        light: UIColor(white: 0, alpha: 0.66)
    )
    static let tertiaryText = adaptive(
        dark: UIColor(white: 1, alpha: 0.52),
        light: UIColor(white: 0, alpha: 0.52)
    )
    static let accent = adaptive(
        dark: UIColor(red: 0.188, green: 0.82, blue: 0.345, alpha: 1),
        light: UIColor(red: 0.039, green: 0.49, blue: 0.22, alpha: 1)
    )
    static let accentDeep = adaptive(
        dark: UIColor(red: 0.075, green: 0.64, blue: 0.27, alpha: 1),
        light: UIColor(red: 0.020, green: 0.36, blue: 0.15, alpha: 1)
    )
    static let onAccent = adaptive(
        dark: UIColor(white: 0, alpha: 0.92),
        light: UIColor(white: 1, alpha: 0.96)
    )
    static let danger = adaptive(
        dark: UIColor(red: 1.0, green: 0.27, blue: 0.23, alpha: 1),
        light: UIColor(red: 0.77, green: 0.17, blue: 0.14, alpha: 1)
    )
    static let warning = adaptive(
        dark: UIColor(red: 1.0, green: 0.62, blue: 0.04, alpha: 1),
        light: UIColor(red: 0.66, green: 0.36, blue: 0.0, alpha: 1)
    )
    static let blue = adaptive(
        dark: UIColor(red: 0.35, green: 0.56, blue: 1.0, alpha: 1),
        light: UIColor(red: 0.18, green: 0.39, blue: 0.85, alpha: 1)
    )
    static let shadow = adaptive(
        dark: UIColor(white: 0, alpha: 0.26),
        light: UIColor(white: 0, alpha: 0.12)
    )
    static let shadowSoft = adaptive(
        dark: UIColor(white: 0, alpha: 0.10),
        light: UIColor(white: 0, alpha: 0.06)
    )
    static let cardEdge = adaptive(
        dark: UIColor(white: 1, alpha: 0.18),
        light: UIColor(white: 0, alpha: 0.07)
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.background

            LinearGradient(
                colors: atmosphere.backgroundColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [atmosphere.glowColor(for: colorScheme), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [Theme.blue.opacity(colorScheme == .dark ? 0.055 : 0.035), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 560
            )

            WeatherSkyLayer()
        }
        .animation(
            Motion.resolved(.easeInOut(duration: 1.1), reduceMotion: reduceMotion),
            value: atmosphere
        )
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18

    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if atmosphere.isPrecipitation {
                    RainCardSurface(intensity: atmosphere.precipitationIntensity)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.cardSurface)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.primaryText.opacity(colorScheme == .dark ? 0.045 : 0.025),
                                    Theme.primaryText.opacity(0.006)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Theme.cardEdge,
                                Theme.stroke.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Theme.shadow, radius: 14, y: 7)
    }
}

private struct RainCardSurface: View {
    let intensity: Double
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.cardSurface)
            RainDropletTexture(intensity: intensity, seed: 8.1)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .opacity(colorScheme == .dark ? 0.22 : 0.14)
        }
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
            .foregroundStyle(Theme.onAccent)
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
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.38), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Theme.accent.opacity(configuration.isPressed ? 0.10 : 0.22), radius: 18, y: 9)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .opacity(configuration.isPressed ? 0.90 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.impact(.light) }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.surfaceStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 0.8)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.primaryText.opacity(configuration.isPressed ? 0.04 : 0))
            )
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
            .font(.footnote.weight(.medium))
            .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Theme.accent : Theme.surfaceStrong)
            )
            .overlay(
                Capsule()
                    .stroke(selected ? Theme.accent.opacity(0.6) : Theme.stroke, lineWidth: 0.8)
            )
            .animation(Motion.quick, value: selected)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
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
                .foregroundStyle(Theme.primaryText)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 28)
    }
}
