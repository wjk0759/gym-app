import SwiftUI

/// Watch counterpart of the iPhone `Theme` palette.
///
/// The watch always runs on a near-black canvas, so it uses the dark values:
/// acid lime for action, graphite for support, warm white for ink.
enum WatchTheme {
    static let canvas = Color(red: 0.035, green: 0.035, blue: 0.035)
    static let surface = Color(red: 0.090, green: 0.090, blue: 0.090)
    static let surfaceRaised = Color(red: 0.140, green: 0.140, blue: 0.140)
    static let ink = Color(red: 0.965, green: 0.965, blue: 0.945)
    static let secondary = Color(red: 0.650, green: 0.650, blue: 0.680)
    static let primary = Color(red: 0.840, green: 1.000, blue: 0.300)
    static let onPrimary = Color(red: 0.040, green: 0.040, blue: 0.040)
    static let warning = Color(red: 1.000, green: 0.620, blue: 0.240)
    static let stroke = ink.opacity(0.10)
}

/// Full-width lime action button. Black label on lime is the same contrast
/// pair used by the iPhone primary button.
struct WatchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground = isEnabled
            ? WatchTheme.onPrimary
            : WatchTheme.secondary
        let background = isEnabled
            ? WatchTheme.primary
            : WatchTheme.surfaceRaised

        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isEnabled ? .clear : WatchTheme.stroke,
                        lineWidth: 1
                    )
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Compact lime capsule for actions that sit inside a card, such as
/// "next exercise" during the final rest.
struct WatchCompactPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let foreground = isEnabled
            ? WatchTheme.onPrimary
            : WatchTheme.secondary
        let background = isEnabled
            ? WatchTheme.primary
            : WatchTheme.surfaceRaised
        return configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// Square graphite icon control for pause and undo.
struct WatchIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(
                isEnabled
                    ? WatchTheme.ink
                    : WatchTheme.secondary.opacity(0.5)
            )
            .frame(width: 40, height: 40)
            .background(
                WatchTheme.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(WatchTheme.stroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Quiet graphite control for pause, undo and secondary actions.
struct WatchSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(WatchTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                WatchTheme.surfaceRaised,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(WatchTheme.stroke, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Three-point progress rail under the training header.
struct WatchProgressBar: View {
    let completed: Int
    let planned: Int

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, planned)
            let ratio = min(1, max(0, Double(completed) / Double(total)))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WatchTheme.ink.opacity(0.08))
                Capsule()
                    .fill(WatchTheme.primary)
                    .frame(width: proxy.size.width * CGFloat(ratio))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

/// Two-dot page indicator shared by training and demo pages.
struct WatchPageDots: View {
    let index: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { value in
                Circle()
                    .fill(
                        value == index
                            ? WatchTheme.primary
                            : WatchTheme.secondary.opacity(0.35)
                    )
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}
