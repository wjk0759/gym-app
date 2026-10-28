import SwiftUI

/// A restrained Apple-style glass surface.
///
/// Real blur is reserved for the coach input and native navigation. Cards use
/// a translucent tint + highlight instead, which keeps the material look
/// without paying for a blur per row.
struct GlassSurface: View {
    var cornerRadius: CGFloat = 22
    var material: Bool = false
    var tint: Color = Theme.cardSurface

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if material {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    tint.opacity(colorScheme == .dark ? 0.58 : 0.54)
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.07 : 0.34),
                            Color.white.opacity(0.01),
                            Color.black.opacity(colorScheme == .dark ? 0.06 : 0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = 18
    var cornerRadius: CGFloat = 22
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
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.24 : 0.72),
                                Theme.stroke.opacity(0.58),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Theme.shadow.opacity(colorScheme == .dark ? 0.52 : 0.30),
                radius: material ? 18 : 10,
                y: material ? 8 : 4
            )
    }
}

extension View {
    /// Use `material: true` only for floating/primary surfaces.
    func glassCard(
        padding: CGFloat = 18,
        cornerRadius: CGFloat = 22,
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
                            Color.white.opacity(0.52),
                            Theme.stroke.opacity(0.42)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }
}
