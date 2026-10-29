import SwiftUI

/// Static cinematic backdrop: a mesh-style set of color fields, key light and
/// film grain. Everything is resolved once by the compositor; there is no
/// Canvas, TimelineView or blur, so sheets and navigation pushes stay cheap.
struct AmbientBackdrop: View {
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark

        ZStack {
            LinearGradient(
                colors: atmosphere.backgroundColors(for: colorScheme),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Mesh-style color fields.
            RadialGradient(
                colors: [atmosphere.glowColor(for: colorScheme), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 540
            )

            RadialGradient(
                colors: [
                    Theme.accentTertiary.opacity(dark ? 0.14 : 0.055),
                    .clear
                ],
                center: UnitPoint(x: 0.88, y: 0.08),
                startRadius: 10,
                endRadius: 430
            )

            RadialGradient(
                colors: [
                    Theme.accentSecondary.opacity(dark ? 0.10 : 0.045),
                    .clear
                ],
                center: UnitPoint(x: 0.12, y: 0.94),
                startRadius: 20,
                endRadius: 540
            )

            // Cinematic key light from the top-left, vignette toward the bottom-right.
            LinearGradient(
                colors: [
                    Color.white.opacity(dark ? 0.045 : 0.16),
                    .clear,
                    Color.black.opacity(dark ? 0.28 : 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GrainTexture(opacity: dark ? 0.05 : 0.022)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
