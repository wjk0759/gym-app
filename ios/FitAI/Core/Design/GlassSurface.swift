import SwiftUI

/// A flat paper surface with an ink hairline.
///
/// The old frosted material read as “app chrome”; this version behaves like a
/// printed card in a training journal. `material` is kept for source
/// compatibility but no longer installs a blur layer.
struct GlassSurface: View {
    var cornerRadius: CGFloat = AppLayout.cardCornerRadius
    var material: Bool = false
    var tint: Color = Theme.cardSurface

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.softLight)
        }
    }
}

/// Quiet control surface: paper fill and one ink hairline.
struct SoftSurface: View {
    var cornerRadius: CGFloat = AppLayout.controlCornerRadius
    var tint: Color = Theme.cardSurface
    var stroke: Color = Theme.stroke

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
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
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }
}

/// Hero-level paper card: a heavier ink rule and a hard offset shadow.
/// Used sparingly for the one card that should stop the scroll.
struct EditorialCardModifier: ViewModifier {
    var padding: CGFloat = AppLayout.cardPadding
    var cornerRadius: CGFloat = AppLayout.heroCornerRadius
    var accent: Color = Theme.cobalt

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.paper)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.ink, lineWidth: 1.5)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 54, height: 5)
                    .clipShape(Capsule())
                    .padding(.leading, padding)
                    .padding(.top, 10)
            }
            .shadow(color: Theme.ink.opacity(0.12), radius: 0, x: 5, y: 5)
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

    func editorialCard(
        padding: CGFloat = AppLayout.cardPadding,
        cornerRadius: CGFloat = AppLayout.heroCornerRadius,
        accent: Color = Theme.cobalt
    ) -> some View {
        modifier(
            EditorialCardModifier(
                padding: padding,
                cornerRadius: cornerRadius,
                accent: accent
            )
        )
    }

    func glassCapsule(material: Bool = false) -> some View {
        background {
            GlassSurface(cornerRadius: 999, material: material)
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
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
