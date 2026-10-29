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
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    static func tap() {
        lightImpact.prepare()
        lightImpact.impactOccurred(intensity: 0.7)
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light, .soft:
            generator = lightImpact
        case .medium:
            generator = mediumImpact
        case .heavy, .rigid:
            generator = heavyImpact
        @unknown default:
            generator = lightImpact
        }
        generator.prepare()
        generator.impactOccurred()
    }

    static func select() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }
}

/// Native-like press highlight for card and compact buttons.
struct CardPressStyle: ButtonStyle {
    var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

/// Native-like press highlight for compact controls.
struct SubtlePressStyle: ButtonStyle {
    var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
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

/// 训练重量/次数的大号加减控件：
/// 大触控区、长按连续调整、点中间数字精确输入。
struct ValueStepperControl: View {
    let title: String
    let value: String
    let unit: String?
    var hint: String? = nil
    var canDecrease: Bool = true
    var canIncrease: Bool = true
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    var onEdit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 4)
                if let hint {
                    Text(hint)
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            HStack(spacing: 8) {
                stepButton(symbol: "minus", enabled: canDecrease, action: onDecrease)
                centerValue
                stepButton(symbol: "plus", enabled: canIncrease, action: onIncrease)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    @ViewBuilder
    private var centerValue: some View {
        if let onEdit {
            Button {
                Haptics.tap()
                onEdit()
            } label: {
                valueDisplay
                    .overlay(alignment: .trailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.accent.opacity(0.8))
                            .padding(.trailing, 11)
                            .allowsHitTesting(false)
                    }
            }
            .buttonStyle(SubtlePressStyle(scale: 0.98))
            .accessibilityLabel("\(title) \(value) \(unit ?? "")")
            .accessibilityHint("点击精确输入")
        } else {
            valueDisplay
        }
    }

    private var valueDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .motionAnimation(Motion.quick, value: value)
            if let unit {
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            Color(.secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stepButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 54, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "minus" ? "减少\(title)" : "增加\(title)")
        .accessibilityHint("长按连续调整")
    }
}
