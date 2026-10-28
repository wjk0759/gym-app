import Foundation
import SwiftUI

/// 轻量水珠纹理：只画静态 Canvas，不跑逐帧动画，避免雨天额外耗电。
struct RainDropletTexture: View {
    var intensity: Double = 0.5
    var seed: Double = 1

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let count = max(8, Int(16 + intensity * 34))
            let highlight = colorScheme == .dark
                ? Color.white
                : Color(red: 0.22, green: 0.40, blue: 0.52)

            for index in 0..<count {
                let x = fraction(sin(Double(index) * 12.9898 + seed) * 43_758.5453) * size.width
                let y = fraction(sin(Double(index) * 78.233 + seed * 3.7) * 19_837.421) * size.height
                let scale = 0.45 + fraction(sin(Double(index) * 39.346 + seed) * 11_371.337) * 1.1
                let width = (1.1 + intensity * 3.0) * scale
                let height = width * (1.2 + fraction(sin(Double(index) * 5.123 + seed) * 9_871.123) * 1.4)

                let rect = CGRect(x: x, y: y, width: width, height: height)
                let drop = Path(ellipseIn: rect)

                context.fill(
                    drop,
                    with: .radialGradient(
                        Gradient(colors: [
                            highlight.opacity(0.52),
                            highlight.opacity(0.08),
                            highlight.opacity(0.01)
                        ]),
                        center: CGPoint(x: rect.minX + width * 0.36, y: rect.minY + height * 0.28),
                        startRadius: 0,
                        endRadius: max(width, height)
                    )
                )
                context.stroke(drop, with: .color(highlight.opacity(0.24)), lineWidth: 0.5)

                let trail = Path { path in
                    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY + height * 1.8))
                }
                context.stroke(
                    trail,
                    with: .linearGradient(
                        Gradient(colors: [highlight.opacity(0.16), .clear]),
                        startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY + height * 1.8)
                    ),
                    lineWidth: max(0.5, width * 0.24)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fraction(_ value: Double) -> Double {
        value - floor(value)
    }
}

/// 下雨时覆盖在页面上的极轻水珠层，不拦截任何交互。
struct RainGlassOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var intensity: Double

    var body: some View {
        RainDropletTexture(intensity: intensity, seed: 4.2)
            .opacity(colorScheme == .dark ? 0.24 : 0.15)
            .blendMode(colorScheme == .dark ? .screen : .normal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
            .allowsHitTesting(false)
    }
}
