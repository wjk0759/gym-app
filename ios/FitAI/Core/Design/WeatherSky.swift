import Foundation
import SwiftUI

/// 天气动画层：太阳、月亮、云、雨、雪、风、雾、闪电都在这里画。
/// 放在 AppBackground 的最底层，不拦截任何交互；10fps、后台自动暂停。
struct WeatherSkyLayer: View {
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.keyboardVisible) private var keyboardVisible

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: paused)) { timeline in
            Canvas { context, size in
                draw(
                    context: &context,
                    size: size,
                    time: timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var paused: Bool {
        reduceMotion || scenePhase != .active || keyboardVisible
    }

    private var isLight: Bool {
        colorScheme == .light
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard size.width > 0, size.height > 0 else { return }

        drawStars(context: &context, size: size, time: time)
        drawCelestial(context: &context, size: size, time: time)
        drawClouds(context: &context, size: size, time: time)

        if atmosphere.kind == .fog {
            drawFog(context: &context, size: size, time: time)
        }

        if atmosphere.isSnow {
            drawSnow(context: &context, size: size, time: time)
        } else if atmosphere.isPrecipitation {
            drawRain(context: &context, size: size, time: time)
        }

        if atmosphere.isWindy {
            drawWind(context: &context, size: size, time: time)
        }

        if atmosphere.kind.isStorm {
            drawLightning(context: &context, size: size, time: time)
        }

        if atmosphere.phase == .morning,
           !atmosphere.isPrecipitation,
           atmosphere.cloudiness < 0.55 {
            drawBirds(context: &context, size: size, time: time)
        }
    }

    // MARK: - 太阳 / 月亮 / 星

    private func drawStars(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard atmosphere.phase == .night else { return }
        let cover = 1 - atmosphere.cloudiness
        guard cover > 0.12 else { return }

        let count = Int(14 + cover * 34)
        let color = isLight
            ? Color(red: 0.12, green: 0.24, blue: 0.38)
            : Color.white

        for index in 0..<count {
            let x = CGFloat(weatherSkyNoise(index, 1.7)) * size.width
            let y = CGFloat(weatherSkyNoise(index, 8.2)) * size.height * 0.68
            let radius = CGFloat(0.45 + weatherSkyNoise(index, 3.1) * 1.05)
            let twinkle = 0.45 + 0.35 * (0.5 + 0.5 * sin(time * 1.3 + Double(index) * 1.7))
            let opacity = twinkle * cover

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity(opacity))
            )

            if index % 11 == 0 {
                var cross = Path()
                cross.move(to: CGPoint(x: x - radius * 2.4, y: y + radius))
                cross.addLine(to: CGPoint(x: x + radius * 2.4, y: y + radius))
                cross.move(to: CGPoint(x: x + radius, y: y - radius * 1.4))
                cross.addLine(to: CGPoint(x: x + radius, y: y + radius * 3.4))
                context.stroke(cross, with: .color(color.opacity(opacity * 0.55)), lineWidth: 0.6)
            }
        }
    }

    private func drawCelestial(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let visibility = atmosphere.celestialVisibility
        guard visibility > 0.01 else { return }

        let center = celestialCenter(in: size)
        let radius = min(size.width, size.height) * CGFloat(atmosphere.phase == .night ? 0.044 : 0.062)
        let color = celestialColor

        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius * 5.5,
                    y: center.y - radius * 5.5,
                    width: radius * 11,
                    height: radius * 11
                )
            ),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(0.23 * visibility),
                    color.opacity(0.055 * visibility),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius * 5.5
            )
        )

        if atmosphere.phase != .night, visibility > 0.42 {
            let rayCount = 7
            for index in 0..<rayCount {
                let angle = Double(index) / Double(rayCount) * .pi * 2 + time * 0.025
                let inner = radius * 1.45
                let outer = radius * CGFloat(1.8 + 0.12 * sin(time * 0.35 + Double(index)))
                var ray = Path()
                ray.move(
                    to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * inner,
                        y: center.y + CGFloat(sin(angle)) * inner
                    )
                )
                ray.addLine(
                    to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * outer,
                        y: center.y + CGFloat(sin(angle)) * outer
                    )
                )
                context.stroke(
                    ray,
                    with: .color(color.opacity(0.13 * visibility)),
                    lineWidth: 1
                )
            }
        }

        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.95 * visibility),
                    color.opacity(0.78 * visibility),
                    color.opacity(0.48 * visibility)
                ]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )

        if atmosphere.phase == .night {
            // 月面暗斑，让月亮不是一颗纯色圆点。
            let spots: [(CGFloat, CGFloat, CGFloat)] = [
                (-0.22, -0.18, 0.16),
                (0.20, 0.10, 0.12),
                (-0.02, 0.28, 0.09)
            ]
            for spot in spots {
                let rect = CGRect(
                    x: center.x + spot.0 * radius,
                    y: center.y + spot.1 * radius,
                    width: spot.2 * radius * 2,
                    height: spot.2 * radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color(red: 0.30, green: 0.40, blue: 0.56).opacity(0.10))
                )
            }
        }
    }

    private func celestialCenter(in size: CGSize) -> CGPoint {
        switch atmosphere.phase {
        case .morning:
            return CGPoint(x: size.width * 0.19, y: size.height * 0.24)
        case .noon:
            return CGPoint(x: size.width * 0.77, y: size.height * 0.14)
        case .evening:
            return CGPoint(x: size.width * 0.83, y: size.height * 0.29)
        case .night:
            return CGPoint(x: size.width * 0.77, y: size.height * 0.17)
        }
    }

    private var celestialColor: Color {
        switch atmosphere.phase {
        case .morning:
            return Color(red: 1.0, green: 0.73, blue: 0.46)
        case .noon:
            return Color(red: 1.0, green: 0.88, blue: 0.55)
        case .evening:
            return Color(red: 1.0, green: 0.50, blue: 0.28)
        case .night:
            return Color(red: 0.78, green: 0.86, blue: 1.0)
        }
    }

    // MARK: - 云

    private func drawClouds(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let count = cloudCount
        guard count > 0 else { return }

        let baseScale = min(size.width, size.height) * 0.17
        let speed = 0.004 + atmosphere.windIntensity * 0.032
        let sun = celestialCenter(in: size)
        let opacity = cloudOpacity
        let bases: [(x: Double, y: Double, scale: CGFloat)] = [
            (0.15, 0.17, 1.15),
            (0.52, 0.27, 0.90),
            (0.82, 0.33, 1.30),
            (0.34, 0.43, 0.72),
            (0.68, 0.12, 0.62)
        ]
        var clouds: [(center: CGPoint, scale: CGFloat)] = []

        for index in 0..<count {
            let base = bases[index % bases.count]
            let cloudScale = baseScale * base.scale
            let center: CGPoint

            if index == 0, atmosphere.kind == .partlyCloudy || atmosphere.kind == .mostlyClear {
                // 让一片云刚好挡在太阳/月亮前面，形成“云层后面隐约透光”。
                center = CGPoint(
                    x: sun.x + CGFloat(sin(time * 0.035 + Double(index))) * cloudScale * 0.65,
                    y: sun.y + CGFloat(cos(time * 0.026)) * cloudScale * 0.32
                )
            } else {
                let normalizedX = weatherSkyWrap(
                    base.x + time * speed + Double(index) * 0.13
                )
                let x = CGFloat(normalizedX) * (size.width + cloudScale * 3) - cloudScale * 1.5
                let y = CGFloat(base.y) * size.height + CGFloat(sin(time * 0.08 + Double(index))) * size.height * 0.006
                center = CGPoint(x: x, y: y)
            }

            clouds.append((center: center, scale: cloudScale))
        }

        let color = cloudColor
        let alpha = color.opacity(opacity * 0.28)
        let parts: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (-0.95, -0.20, 0.95, 0.65),
            (-0.45, -0.43, 0.90, 0.85),
            (0.10, -0.50, 1.10, 0.95),
            (0.65, -0.22, 0.90, 0.70),
            (1.00, 0.00, 0.65, 0.50)
        ]

        // 不再每帧对云层做 blur：低透明度的多层椭圆已经足够形成软边，
        // 在滚动和输入时能明显减少合成开销。
        for cloud in clouds {
            for part in parts {
                let rect = CGRect(
                    x: cloud.center.x + part.0 * cloud.scale,
                    y: cloud.center.y + part.1 * cloud.scale,
                    width: part.2 * cloud.scale,
                    height: part.3 * cloud.scale
                )
                context.fill(Path(ellipseIn: rect), with: .color(alpha))
            }
        }
    }

    private var cloudCount: Int {
        if atmosphere.isPrecipitation {
            return 4
        }
        switch atmosphere.kind {
        case .clear: return 0
        case .mostlyClear: return 2
        case .partlyCloudy: return 4
        case .overcast: return 5
        case .fog: return 3
        case .unknown: return 2
        default: return 3
        }
    }

    private var cloudOpacity: Double {
        if atmosphere.isPrecipitation || atmosphere.kind == .overcast {
            return 0.76
        }
        switch atmosphere.kind {
        case .clear: return 0
        case .mostlyClear: return 0.20
        case .partlyCloudy: return 0.56
        case .fog: return 0.48
        default: return 0.34
        }
    }

    private var cloudColor: Color {
        if atmosphere.isPrecipitation || atmosphere.kind == .overcast {
            return isLight
                ? Color(red: 0.52, green: 0.60, blue: 0.65)
                : Color(red: 0.42, green: 0.52, blue: 0.62)
        }
        if atmosphere.kind == .fog {
            return isLight
                ? Color(red: 0.72, green: 0.77, blue: 0.78)
                : Color(red: 0.56, green: 0.64, blue: 0.70)
        }
        switch atmosphere.phase {
        case .morning:
            return isLight
                ? Color(red: 0.96, green: 0.91, blue: 0.86)
                : Color(red: 0.68, green: 0.62, blue: 0.64)
        case .noon:
            return isLight
                ? Color(red: 0.86, green: 0.89, blue: 0.89)
                : Color(red: 0.74, green: 0.82, blue: 0.87)
        case .evening:
            return isLight
                ? Color(red: 0.95, green: 0.79, blue: 0.72)
                : Color(red: 0.70, green: 0.55, blue: 0.56)
        case .night:
            return isLight
                ? Color(red: 0.72, green: 0.77, blue: 0.84)
                : Color(red: 0.30, green: 0.38, blue: 0.52)
        }
    }

    // MARK: - 雨 / 雪 / 风 / 雾

    private func drawRain(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let intensity = atmosphere.precipitationIntensity
        guard intensity > 0 else { return }

        let count = min(108, 36 + Int(intensity * 72))
        let wind = atmosphere.windIntensity
        let color = rainColor
        let fade = isLight ? 0.72 : 1.0
        // 雨滴数量多，使用纯色描边而不是每滴创建一个渐变对象，避免天气动画抢主线程。
        let opacity = (0.18 + intensity * 0.24) * fade
        let lineWidth = CGFloat(0.7 + intensity * 0.9)

        for index in 0..<count {
            let fall = 0.55 + weatherSkyNoise(index, 1.1) * 0.55
            let yNorm = weatherSkyWrap(weatherSkyNoise(index, 2.2) + time * fall * 0.55)
            let xNorm = weatherSkyWrap(
                weatherSkyNoise(index, 3.4) + time * (0.018 + wind * 0.10)
            )
            let x = CGFloat(xNorm) * size.width * 1.12 - size.width * 0.06
            let y = CGFloat(yNorm) * size.height
            let length = CGFloat((6 + weatherSkyNoise(index, 4.5) * 17) * (0.65 + intensity))
            let slant = CGFloat(1.5 + wind * 22)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - slant, y: y + length))
            context.stroke(
                path,
                with: .color(color.opacity(opacity)),
                lineWidth: lineWidth
            )
        }

        // 地面积水的细小涟漪。
        for index in 0..<8 {
            let pulse = weatherSkyWrap(weatherSkyNoise(index, 8.1) + time * 0.75)
            let x = CGFloat(weatherSkyNoise(index, 9.2)) * size.width
            let y = size.height * CGFloat(0.80 + weatherSkyNoise(index, 10.3) * 0.14)
            let radius = CGFloat(1.2 + pulse * 4.8)
            let rect = CGRect(
                x: x - radius,
                y: y - radius * 0.26,
                width: radius * 2,
                height: radius * 0.52
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(color.opacity((1 - pulse) * 0.16 * fade)),
                lineWidth: 0.7
            )
        }
    }

    private func drawSnow(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let intensity = atmosphere.precipitationIntensity
        let count = min(94, 40 + Int(intensity * 54))
        let wind = atmosphere.windIntensity
        let color = snowColor
        let fade = isLight ? 0.72 : 1.0

        for index in 0..<count {
            let seed = Double(index)
            let fall = 0.012 + weatherSkyNoise(index, 1.5) * 0.020
            let yNorm = weatherSkyWrap(weatherSkyNoise(index, 2.3) + time * fall)
            let sway = sin(time * 0.6 + seed * 1.8) * 0.012
            let xNorm = weatherSkyWrap(
                weatherSkyNoise(index, 3.7) + sway + time * wind * 0.018
            )
            let x = CGFloat(xNorm) * size.width
            let y = CGFloat(yNorm) * size.height
            let radius = CGFloat(0.8 + weatherSkyNoise(index, 4.4) * 2.1)

            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                with: .color(color.opacity((0.32 + weatherSkyNoise(index, 5.1) * 0.35) * fade))
            )

            if index % 17 == 0 {
                var cross = Path()
                cross.move(to: CGPoint(x: x - radius * 1.8, y: y + radius))
                cross.addLine(to: CGPoint(x: x + radius * 1.8, y: y + radius))
                cross.move(to: CGPoint(x: x + radius, y: y - radius * 0.8))
                cross.addLine(to: CGPoint(x: x + radius, y: y + radius * 2.8))
                context.stroke(cross, with: .color(color.opacity(0.24 * fade)), lineWidth: 0.6)
            }
        }
    }

    private func drawWind(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let wind = atmosphere.windIntensity
        guard wind > 0.12 else { return }

        let color = windColor
        let count = 3 + Int(wind * 5)
        for index in 0..<count {
            let progress = weatherSkyWrap(
                weatherSkyNoise(index, 1.3) + time * (0.04 + wind * 0.20)
            )
            let x = CGFloat(progress) * size.width * 1.25 - size.width * 0.12
            let y = CGFloat(0.12 + weatherSkyNoise(index, 2.2) * 0.64) * size.height + CGFloat(sin(time * 0.9 + Double(index))) * size.height * 0.008
            let length = size.width * CGFloat(0.12 + wind * 0.18)
            let lift = CGFloat(4 + wind * 12)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(
                to: CGPoint(x: x + length, y: y - lift),
                control1: CGPoint(x: x + length * 0.35, y: y - lift * 0.2),
                control2: CGPoint(x: x + length * 0.72, y: y - lift * 1.3)
            )
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        .clear,
                        color.opacity(0.12 + wind * 0.25),
                        .clear
                    ]),
                    startPoint: CGPoint(x: x, y: y),
                    endPoint: CGPoint(x: x + length, y: y - lift)
                ),
                lineWidth: CGFloat(0.8 + wind * 1.5)
            )
        }

        if atmosphere.isTyphoon {
            let center = CGPoint(x: size.width * 0.18, y: size.height * 0.34)
            for index in 0..<3 {
                let radius = min(size.width, size.height) * CGFloat(0.17 + Double(index) * 0.075)
                let start = Angle(radians: time * 0.55 + Double(index) * 2.1)
                let end = Angle(radians: start.radians + 2.15)
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(color.opacity(0.13)),
                    lineWidth: 1.4
                )
            }

            // 被风卷起的碎叶/尘点。
            for index in 0..<10 {
                let progress = weatherSkyWrap(
                    weatherSkyNoise(index, 6.2) + time * (0.10 + wind * 0.32)
                )
                let x = CGFloat(progress) * size.width
                let y = CGFloat(0.32 + weatherSkyNoise(index, 7.4) * 0.42) * size.height
                let radius = CGFloat(0.8 + weatherSkyNoise(index, 8.3) * 1.3)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2.4, height: radius)),
                    with: .color(color.opacity(0.12 + wind * 0.10))
                )
            }
        }
    }

    private func drawFog(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let color = fogColor
        for index in 0..<4 {
            let progress = weatherSkyWrap(
                Double(index) * 0.23 + time * 0.006
            )
            let x = CGFloat(progress) * size.width * 1.25 - size.width * 0.12
            let y = size.height * CGFloat(0.20 + Double(index) * 0.14)
            let width = size.width * CGFloat(0.82 + weatherSkyNoise(index, 3.8) * 0.22)
            let rect = CGRect(
                x: x,
                y: y,
                width: width,
                height: size.height * 0.10
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        color.opacity(0.15),
                        color.opacity(0.05),
                        .clear
                    ]),
                    center: CGPoint(x: rect.midX, y: rect.midY),
                    startRadius: 0,
                    endRadius: max(rect.width, rect.height) * 0.55
                )
            )
        }
    }

    // MARK: - 闪电 / 鸟

    private func drawLightning(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let cycle = time.truncatingRemainder(dividingBy: 6.5)
        let flashing = cycle < 0.08 || (cycle > 0.17 && cycle < 0.21)
        guard flashing else { return }

        var flash = Path()
        flash.addRect(CGRect(origin: .zero, size: size))
        context.fill(
            flash,
            with: .color(Color.white.opacity(isLight ? 0.02 : 0.035))
        )

        let origin = CGPoint(x: size.width * 0.72, y: size.height * 0.10)
        var bolt = Path()
        bolt.move(to: origin)
        bolt.addLine(to: CGPoint(x: origin.x - size.width * 0.035, y: origin.y + size.height * 0.08))
        bolt.addLine(to: CGPoint(x: origin.x + size.width * 0.010, y: origin.y + size.height * 0.10))
        bolt.addLine(to: CGPoint(x: origin.x - size.width * 0.045, y: origin.y + size.height * 0.19))
        context.stroke(bolt, with: .color(Color.white.opacity(0.55)), lineWidth: 1.4)
    }

    private func drawBirds(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let color = isLight
            ? Color(red: 0.20, green: 0.28, blue: 0.30)
            : Color.white.opacity(0.42)

        for index in 0..<3 {
            let progress = weatherSkyWrap(
                weatherSkyNoise(index, 4.2) + time * (0.005 + Double(index) * 0.0015)
            )
            let x = CGFloat(progress) * size.width
            let y = size.height * CGFloat(0.18 + Double(index) * 0.045)
            let wing = CGFloat(3 + index)

            var bird = Path()
            bird.move(to: CGPoint(x: x - wing, y: y))
            bird.addLine(to: CGPoint(x: x, y: y - wing * 0.55))
            bird.addLine(to: CGPoint(x: x + wing, y: y))
            context.stroke(bird, with: .color(color.opacity(0.24)), lineWidth: 0.8)
        }
    }

    // MARK: - 配色

    private var rainColor: Color {
        isLight
            ? Color(red: 0.26, green: 0.44, blue: 0.56)
            : Color(red: 0.72, green: 0.86, blue: 1.0)
    }

    private var snowColor: Color {
        isLight
            ? Color(red: 0.30, green: 0.48, blue: 0.62)
            : Color(red: 0.88, green: 0.95, blue: 1.0)
    }

    private var windColor: Color {
        isLight
            ? Color(red: 0.22, green: 0.42, blue: 0.54)
            : Color(red: 0.72, green: 0.86, blue: 1.0)
    }

    private var fogColor: Color {
        isLight
            ? Color(red: 0.48, green: 0.57, blue: 0.61)
            : Color(red: 0.63, green: 0.72, blue: 0.78)
    }
}

private func weatherSkyNoise(_ index: Int, _ salt: Double) -> Double {
    let value = sin(Double(index) * 12.9898 + salt) * 43_758.5453
    return value - floor(value)
}

private func weatherSkyWrap(_ value: Double, _ upper: Double = 1) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: upper)
    return remainder < 0 ? remainder + upper : remainder
}
