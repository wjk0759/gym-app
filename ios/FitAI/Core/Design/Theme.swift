import SwiftUI
import UIKit

enum Theme {
    // MARK: - Four-color system
    //
    // The whole app uses only four color roles:
    // 1. `primary`   — acid lime, the signal color for CTA/selection.
    // 2. `secondary` — graphite, the supporting neutral for muted UI.
    // 3. `canvas`    — system-adaptive background.
    // 4. `ink`       — system-adaptive text and solid surfaces.
    //
    // Black/white card surfaces are the `ink` / `canvas` hierarchy, not a
    // fifth hue. Do not add another accent color.

    /// 1. Primary: acid lime. Always paired with `onPrimary` (black).
    static let primary = adaptive(
        dark: UIColor(red: 0.840, green: 1.000, blue: 0.300, alpha: 1),
        light: UIColor(red: 0.820, green: 0.980, blue: 0.230, alpha: 1)
    )

    /// 2. Secondary: graphite. Used for muted text, inactive icons and
    /// secondary fills. Contrast pair is `onAccent`.
    static let secondary = adaptive(
        dark: UIColor(red: 0.650, green: 0.650, blue: 0.680, alpha: 1),
        light: UIColor(red: 0.420, green: 0.420, blue: 0.450, alpha: 1)
    )

    /// 3. Canvas: light neutral in light mode, near-black in dark mode.
    static let canvas = adaptive(
        dark: UIColor(red: 0.035, green: 0.035, blue: 0.035, alpha: 1),
        light: UIColor(red: 0.949, green: 0.949, blue: 0.941, alpha: 1)
    )

    /// 4. Ink: near-black text in light mode, warm white in dark mode.
    static let ink = adaptive(
        dark: UIColor(red: 0.965, green: 0.965, blue: 0.945, alpha: 1),
        light: UIColor(red: 0.040, green: 0.040, blue: 0.040, alpha: 1)
    )

    // MARK: - Neutral surface hierarchy

    static let background = canvas
    static let cardSurface = adaptive(
        dark: UIColor(red: 0.090, green: 0.090, blue: 0.090, alpha: 1),
        light: UIColor(white: 1, alpha: 1)
    )
    static let paper = cardSurface
    static let chrome = canvas.opacity(0.94)
    static let surface = ink.opacity(0.045)
    static let stroke = ink.opacity(0.12)
    static let primaryText = ink
    static let secondaryText = secondary
    static let tertiaryText = secondary.opacity(0.68)

    /// Text/icon color on ink, graphite or other dark-neutral fills.
    static let onAccent = adaptive(
        dark: UIColor(red: 0.040, green: 0.040, blue: 0.040, alpha: 1),
        light: UIColor(white: 1, alpha: 1)
    )

    /// Text/icon color on the acid-lime primary. Always black for contrast.
    static let onPrimary = Color(red: 0.040, green: 0.040, blue: 0.040)

    static let shadow = adaptive(
        dark: UIColor(white: 0, alpha: 0.45),
        light: UIColor(white: 0, alpha: 0.14)
    )

    // MARK: - Compatibility aliases

    // Old cobalt/blue usages become the system ink color. This is what turns
    // the previous blue UI into the reference's black/white system.
    static let accent = primary
    static let accentWarm = secondary
    static let danger = secondary
    static let warning = secondary
    static let blue = ink
    static let cobalt = ink
    static let lime = primary
    static let coral = secondary

    /// Semantic cycle/period accent. This is the one intentional exception to
    /// the four-color palette: it carries meaning on menstrual-cycle surfaces,
    /// not decoration. It still adapts to light/dark and pairs with `onAccent`.
    static let cycle = adaptive(
        dark: UIColor(red: 1.000, green: 0.560, blue: 0.720, alpha: 1),
        light: UIColor(red: 0.760, green: 0.180, blue: 0.380, alpha: 1)
    )

    /// Always-dark ink used for brand marks, avatars and the capture button.
    /// Unlike `ink` (which follows text color and turns light in dark mode),
    /// this keeps the lime-on-ink identity readable in both appearances.
    static let inkSolid = Color(red: 0.040, green: 0.040, blue: 0.040)

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
            .foregroundStyle(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.primary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
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
            .foregroundStyle(selected ? Theme.onPrimary : Theme.secondaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Theme.primary : Theme.paper)
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

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.primary)
                    .frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
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
