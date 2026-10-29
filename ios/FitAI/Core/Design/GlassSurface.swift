import SwiftUI

/// Native grouped surface. Real material is reserved for floating chrome such
/// as the coach composer and toast; regular cards use the system grouped fill.
struct GlassSurface: View {
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false
    var tint: Color = Theme.cardSurface

    var body: some View {
        ZStack {
            if material {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            }
        }
    }
}

/// Native fill for controls and compact tiles.
struct SoftSurface: View {
    var cornerRadius: CGFloat = AppLayout.controlCornerRadius
    var tint: Color = Theme.surfaceStrong
    var stroke: Color = Theme.stroke

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke.opacity(0.35), lineWidth: 0.5)
            )
    }
}

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = AppLayout.cardPadding
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                GlassSurface(
                    cornerRadius: cornerRadius,
                    material: material
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
