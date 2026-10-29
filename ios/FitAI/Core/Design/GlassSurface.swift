import SwiftUI

/// A restrained Apple-style glass surface.
///
/// Real blur is reserved for the coach input and native navigation. Cards use
/// a translucent tint + highlight instead, which keeps the material look
/// without paying for a blur per row.
struct GlassSurface: View {
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false
    var tint: Color = Theme.cardSurface

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let tintOpacity = dark ? 0.62 : (material ? 0.60 : 0.90)

        ZStack {
            if material {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(tintOpacity))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(dark ? 0.10 : 0.16),
                            Color.white.opacity(0.012),
                            Color.black.opacity(dark ? 0.10 : 0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

/// Soft, extruded surface for controls. Uses a dual-toned fill and a light
/// top / dark bottom hairline instead of a real, per-control shadow.
struct SoftSurface: View {
    var cornerRadius: CGFloat = AppLayout.controlCornerRadius
    var tint: Color = Theme.surfaceStrong
    var stroke: Color = Theme.stroke

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint,
                        tint.opacity(dark ? 0.72 : 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                if !dark {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.018))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(dark ? 0.20 : 0.42),
                                stroke.opacity(0.9),
                                Color.black.opacity(dark ? 0.30 : 0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
    }
}

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = AppLayout.cardPadding
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let dark = colorScheme == .dark

        content
            .padding(padding)
            .background {
                GlassSurface(
                    cornerRadius: cornerRadius,
                    material: material
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: dark
                                ? [
                                    Color.white.opacity(0.30),
                                    Theme.stroke.opacity(0.58),
                                    Color.white.opacity(0.025)
                                ]
                                : [
                                    Color.black.opacity(0.055),
                                    Theme.cardEdge,
                                    Color.black.opacity(0.035)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            // No per-card shadow: scrolling and transitions would composite
            // an offscreen shadow layer every frame. The tint, gradient
            // highlight and hairline keep the glass depth without that cost.
    }
}

extension View {
    /// Use `material: true` only for floating/primary surfaces.
    func glassCard(
        padding: CGFloat = AppLayout.cardPadding,
        cornerRadius: CGFloat = AppLayout.cardCornerRadius,
        material: Bool = false
    ) -> some View {
        modifier(
            GlassCardModifier(
                padding: padding,
                cornerRadius: cornerRadius,
                material: material
            )
        )
    }

    func glassCapsule(material: Bool = false) -> some View {
        background {
            GlassSurface(cornerRadius: 999, material: material)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.58),
                            Theme.stroke.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }

    /// Soft neumorphic control surface: dual-toned fill + light/dark hairline.
    func softSurface(
        cornerRadius: CGFloat = AppLayout.controlCornerRadius,
        tint: Color = Theme.surfaceStrong,
        stroke: Color = Theme.stroke
    ) -> some View {
        background {
            SoftSurface(cornerRadius: cornerRadius, tint: tint, stroke: stroke)
        }
    }
}
