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
            Theme.background

            // Neutral studio light: the canvas stays graphite/paper; lime is
            // reserved for UI signals and never washes the whole page green.
            RadialGradient(
                colors: [
                    Theme.secondary.opacity(dark ? 0.10 : 0.05),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 620
            )

            RadialGradient(
                colors: [
                    Theme.ink.opacity(dark ? 0.08 : 0.03),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 560
            )

            RadialGradient(
                colors: [
                    atmosphere.glowColor(for: colorScheme).opacity(dark ? 0.12 : 0.07),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(dark ? 0.012 : 0.035),
                    .clear,
                    Theme.ink.opacity(dark ? 0.16 : 0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // A whisper of paper grain; static and tiled, no per-frame cost.
            GrainTexture(opacity: dark ? 0.018 : 0.022)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
