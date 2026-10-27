import SwiftUI
import UIKit

/// 全局动效节奏。所有页面共用同一套弹簧参数，避免每个视图各写一套时长。
enum Motion {
    /// 按下/松开等即时反馈。
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.86)
    /// 小范围状态切换：选中、开关、数值。
    static let quick = Animation.spring(response: 0.28, dampingFraction: 0.88)
    /// 页面内模块出现、内容替换。
    static let smooth = Animation.spring(response: 0.42, dampingFraction: 0.88)
    /// 整屏或大块内容切换。
    static let gentle = Animation.spring(response: 0.55, dampingFraction: 0.92)
    /// 带一点回弹的强调动效。
    static let bouncy = Animation.spring(response: 0.40, dampingFraction: 0.74)

    /// 尊重系统「减弱动态效果」。
    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// 统一的触感反馈，避免各处直接 new 生成器。
enum Haptics {
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func select() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

/// 大卡片/导航卡片的按压反馈：轻微缩放 + 变暗 + 一次轻触感。
struct CardPressStyle: ButtonStyle {
    var scale: CGFloat = 0.978

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.93 : 1)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.tap() }
            }
    }
}

/// 小控件（胶囊、图标按钮）的按压反馈：只做缩放，不加触感以免过密。
struct SubtlePressStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

private struct StaggeredIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let index: Int
    let distance: CGFloat
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : distance)
            .onAppear {
                guard !visible else { return }
                if reduceMotion {
                    visible = true
                } else {
                    let delay = min(Double(index) * 0.05, 0.32)
                    withAnimation(Motion.smooth.delay(delay)) {
                        visible = true
                    }
                }
            }
    }
}

private struct MotionAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// 首屏内容依次淡入上浮，营造编排感；系统开启减弱动态效果时直接显示。
    func staggerIn(_ index: Int, distance: CGFloat = 14) -> some View {
        modifier(StaggeredIn(index: index, distance: distance))
    }

    /// 状态变化时使用统一动效，且自动遵守「减弱动态效果」。
    func motionAnimation<Value: Equatable>(
        _ animation: Animation = Motion.smooth,
        value: Value
    ) -> some View {
        modifier(MotionAnimation(animation: animation, value: value))
    }

    /// 内容替换时使用统一的轻柔转场。
    func softContentTransition() -> some View {
        transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 10)).combined(with: .scale(scale: 0.99)),
                removal: .opacity
            )
        )
    }
}

/// 教练「正在输入」的三点跳动，替代系统 ProgressView。
struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.secondaryText)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1 : 0.55)
                    .opacity(animating ? 1 : 0.35)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.55)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}

/// 训练重量/次数的大号加减控件，替代系统 Stepper 的小箭头。
struct ValueStepperControl: View {
    let title: String
    let value: String
    let unit: String?
    var canDecrease: Bool = true
    var canIncrease: Bool = true
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                stepButton(symbol: "minus", enabled: canDecrease, action: onDecrease)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(Motion.quick, value: value)
                    if let unit {
                        Text(unit)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .frame(minWidth: 88)

                stepButton(symbol: "plus", enabled: canIncrease, action: onIncrease)
            }
            .padding(3)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.surfaceStrong)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
            )
        }
    }

    private func stepButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? Theme.accent : Theme.tertiaryText.opacity(0.5))
                .frame(width: 38, height: 34)
                .background(
                    Circle()
                        .fill(enabled ? Theme.accent.opacity(0.12) : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(SubtlePressStyle())
        .disabled(!enabled)
        .accessibilityLabel(symbol == "minus" ? "减少\(title)" : "增加\(title)")
    }
}
