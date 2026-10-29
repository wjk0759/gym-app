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

            // One weather-tinted light source, then a neutral vignette.
            // No rainbow mesh and no grain: both read as plastic at this size.
            RadialGradient(
                colors: [
                    atmosphere.glowColor(for: colorScheme).opacity(0.55),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(dark ? 0.018 : 0.05),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )

            // Soft key light, then a deep vignette for glass to sit on.
            LinearGradient(
                colors: [
                    Color.white.opacity(dark ? 0.018 : 0.06),
                    .clear,
                    Color.black.opacity(dark ? 0.20 : 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
