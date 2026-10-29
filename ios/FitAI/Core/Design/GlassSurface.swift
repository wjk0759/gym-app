import SwiftUI

/// A restrained frosted surface.
///
/// Content cards use `thinMaterial`; floating controls use `regularMaterial`.
/// A single translucent tint and a hairline replace the old gloss gradients,
/// which is what made the first pass read as plastic.
struct GlassSurface: View {
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false
    var tint: Color = Theme.cardSurface

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material ? Material.regularMaterial : Material.thinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    tint.opacity(colorScheme == .dark ? 0.30 : 0.20)
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.055 : 0.12),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}

/// Frosted control surface: translucent material, a flat tint and one hairline.
/// No gradients or inner highlights, so segmented controls and fields stay matte.
struct SoftSurface: View {
    var cornerRadius: CGFloat = AppLayout.controlCornerRadius
    var tint: Color = Theme.surfaceStrong
    var stroke: Color = Theme.stroke

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        stroke.opacity(colorScheme == .dark ? 0.90 : 0.80),
                        lineWidth: 0.6
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
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.10)
                            : Color.black.opacity(0.06),
                        lineWidth: 0.5
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
