import SwiftUI

/// Fixed set logger for the workout pager.
///
/// Weight, reps, step size and the completion action live here so the user
/// never has to switch pages or scroll to record a set. The rest countdown is
/// folded into the same bar instead of taking a separate card.
struct WorkoutSessionLoggerBar: View {
    let exercise: PlanExercise?
    let done: Int
    let nextTitle: String
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var weightStep: Double
    let restRemaining: Int?
    let restTotal: Double
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onSkipRest: () -> Void
    let onSkipRemaining: () -> Void
    let onComplete: () -> Void
    let onAdvance: () -> Void
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var isBodyweight: Bool {
        exercise?.exercise?.equipment == .bodyweight
    }

    private var isDone: Bool {
        guard let exercise else { return false }
        return done >= exercise.sets
    }

    private var summary: String {
        if isBodyweight {
            return "自重 × \(reps) 次"
        }
        return "\(WorkoutWeightFormat.text(weight)) kg × \(reps) 次"
    }

    var body: some View {
        VStack(spacing: 4) {
            if let exercise {
                if isDone {
                    completedContent(exercise)
                } else {
                    activeContent(exercise)
                }
            } else {
                Button("保存并结束") {
                    onFinish()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .appPagePadding()
        .padding(.top, 7)
        .padding(.bottom, 7)
        .background {
            Theme.chrome
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
        .overlay(alignment: .topLeading) {
            restProgressLine
        }
        .motionAnimation(Motion.quick, value: done)
        .motionAnimation(Motion.quick, value: exercise?.id)
    }

    // MARK: - Active set

    private func activeContent(_ exercise: PlanExercise) -> some View {
        VStack(spacing: 4) {
            topRow(exercise)
            steppers
            completionButton(exercise)
        }
    }

    private func topRow(_ exercise: PlanExercise) -> some View {
        HStack(spacing: 6) {
            Text("第 \(done + 1) 组 / 共 \(exercise.sets) 组")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if isBodyweight {
                Text("自重")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Theme.ink.opacity(0.045),
                        in: Capsule(style: .continuous)
                    )
            }

            Spacer(minLength: 4)

            if !isBodyweight {
                stepMenu
                    .fixedSize(horizontal: true, vertical: false)
            }

            if let restRemaining {
                restPill(remaining: restRemaining)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Button("跳过剩余组") {
                    onSkipRemaining()
                }
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
                .frame(height: 24)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .frame(height: 24)
    }

    private var steppers: some View {
        HStack(spacing: 7) {
            if !isBodyweight {
                loggerStepper(
                    title: "重量",
                    value: WorkoutWeightFormat.text(weight),
                    unit: "kg",
                    canDecrease: weight > 0,
                    canIncrease: weight < 300,
                    onDecrease: { adjustWeight(by: -weightStep) },
                    onIncrease: { adjustWeight(by: weightStep) },
                    onEdit: onEditWeight
                )
            }

            loggerStepper(
                title: "次数",
                value: "\(reps)",
                unit: "次",
                canDecrease: reps > 1,
                canIncrease: reps < 60,
                onDecrease: { reps = max(1, reps - 1) },
                onIncrease: { reps = min(60, reps + 1) },
                onEdit: onEditReps
            )
        }
        .sensoryFeedback(.selection, trigger: weight)
        .sensoryFeedback(.selection, trigger: reps)
    }

    private func loggerStepper(
        title: String,
        value: String,
        unit: String,
        canDecrease: Bool,
        canIncrease: Bool,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void,
        onEdit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 5) {
            loggerStepButton(
                title: title,
                symbol: "minus",
                enabled: canDecrease,
                action: onDecrease
            )

            Button {
                Haptics.tap()
                onEdit()
            } label: {
                HStack(spacing: 3) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)

                    Text(unit)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .offset(y: 2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    SoftSurface(
                        cornerRadius: 11,
                        tint: Theme.ink.opacity(0.035),
                        stroke: Theme.stroke
                    )
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            }
            .buttonStyle(SubtlePressStyle(scale: 0.98))
            .accessibilityLabel("\(title) \(value) \(unit)")
            .accessibilityHint("点击精确输入")

            loggerStepButton(
                title: title,
                symbol: "plus",
                enabled: canIncrease,
                action: onIncrease
            )
        }
    }

    private func loggerStepButton(
        title: String,
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(
                    enabled ? Theme.ink : Theme.tertiaryText.opacity(0.35)
                )
                .frame(width: 40, height: 44)
                .background(
                    SoftSurface(
                        cornerRadius: 11,
                        tint: Theme.ink.opacity(0.04),
                        stroke: Theme.stroke
                    )
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
        .accessibilityLabel(
            "\(symbol == "minus" ? "减少" : "增加")\(title)"
        )
        .accessibilityHint("长按连续调整")
    }

    private var stepMenu: some View {
        Menu {
            ForEach([1.25, 2.5, 5.0], id: \.self) { step in
                Button {
                    weightStep = step
                    Haptics.select()
                } label: {
                    if weightStep == step {
                        Label(
                            "\(WorkoutWeightFormat.text(step)) kg",
                            systemImage: "checkmark"
                        )
                    } else {
                        Text("\(WorkoutWeightFormat.text(step)) kg")
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("步进 \(WorkoutWeightFormat.text(weightStep)) kg")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Theme.ink.opacity(0.045),
                in: Capsule(style: .continuous)
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("调整步进")
    }

    private func completionButton(_ exercise: PlanExercise) -> some View {
        Button {
            onComplete()
        } label: {
            Text("完成第 \(done + 1) 组")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel(
            "完成第 \(done + 1) 组，\(summary)"
        )
    }

    // MARK: - Completed exercise

    private func completedContent(_ exercise: PlanExercise) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("本动作完成 · \(done)/\(exercise.sets) 组")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()

                Spacer(minLength: 4)

                if let restRemaining {
                    restPill(remaining: restRemaining)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(height: 24)

            Button(nextTitle) {
                onAdvance()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Rest

    private func restPill(remaining: Int) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.primary)
                .frame(width: 5, height: 5)
                .scaleEffect(pulse ? 1.25 : 0.82)
                .opacity(pulse ? 1 : 0.55)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("休息")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.onMedia.opacity(0.62))

            Text(restText(remaining))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.primary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Button("跳过") {
                Haptics.tap()
                onSkipRest()
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.onMedia.opacity(0.82))
            .buttonStyle(.plain)
            .padding(.leading, 1)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            Theme.inkSolid,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear { pulse = true }
        .onDisappear { pulse = false }
    }

    @ViewBuilder
    private var restProgressLine: some View {
        if let restRemaining, restTotal > 0 {
            GeometryReader { proxy in
                Rectangle()
                    .fill(Theme.primary)
                    .frame(
                        width: proxy.size.width
                            * CGFloat(max(0, min(restRemaining, Int(restTotal))))
                            / CGFloat(max(1, restTotal)),
                        height: 2
                    )
                    .animation(.linear(duration: 1), value: restRemaining)
            }
            .frame(height: 2)
            .allowsHitTesting(false)
        }
    }

    private func restText(_ remaining: Int) -> String {
        let value = max(0, remaining)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private func adjustWeight(by delta: Double) {
        let next = weight + delta
        weight = min(300, max(0, (next * 100).rounded() / 100))
    }
}
