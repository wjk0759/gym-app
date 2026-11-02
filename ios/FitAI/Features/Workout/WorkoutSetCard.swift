import SwiftUI

struct WorkoutSetCard: View {
    let exercise: PlanExercise
    let done: Int
    let lastSet: SetLog?
    let bestSet: SetLog?
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var rpe: Double
    @Binding var weightStep: Double
    let onAdjust: () -> Void
    let onEditWeight: () -> Void
    let onEditReps: () -> Void
    let onUndoLast: () -> Void
    let isLastSetCurrent: Bool

    var body: some View {
        let isBodyweight = exercise.exercise?.equipment == .bodyweight

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("第 \(min(done + 1, exercise.sets)) 组")
                        .font(AppType.title)
                        .foregroundStyle(Theme.ink)
                    Text("共 \(exercise.sets) 组 · 目标 RPE \(exercise.rpe, specifier: "%.1f")")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                Button {
                    onAdjust()
                } label: {
                    Text("调整")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Theme.paper, in: Capsule(style: .continuous))
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))
                .accessibilityHint("调整目标组数、次数、重量和休息")
            }

            if let last = lastSet {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("上次 \(last.weightKG > 0 ? "\(last.weightKG.formatted()) kg × \(last.reps)" : "自重 × \(last.reps)") · RPE \(last.rpe.formatted(.number.precision(.fractionLength(1))))")
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 6)
                    Button("用上次") {
                        weight = last.weightKG
                        reps = last.reps
                        Haptics.select()
                    }
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
                    .buttonStyle(SubtlePressStyle())
                    .accessibilityLabel("使用上次的重量和次数")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .padding(9)
                .background(
                    Theme.ink.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }

            if let best = bestSet {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Theme.warning)
                    Text("历史最佳 \(best.weightKG > 0 ? "\(best.weightKG.formatted()) kg × \(best.reps)" : "自重 × \(best.reps)")")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("本组数据")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 4)
                }

                if !isBodyweight {
                    ValueStepperControl(
                        title: "本组重量",
                        value: WorkoutWeightFormat.text(weight),
                        unit: "kg",
                        hint: "步进 \(WorkoutWeightFormat.text(weightStep)) kg",
                        canDecrease: weight > 0,
                        canIncrease: weight < 300,
                        onDecrease: { weight = max(0, weight - weightStep) },
                        onIncrease: { weight = min(300, weight + weightStep) },
                        onEdit: { onEditWeight() }
                    )

                    WorkoutWeightStepPicker(weightStep: $weightStep)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.functional")
                        Text("自重动作，直接填写本组实际次数")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }

                ValueStepperControl(
                    title: "实际次数",
                    value: "\(reps)",
                    unit: "次",
                    hint: "目标 \(exercise.reps) 次",
                    canDecrease: reps > 1,
                    canIncrease: reps < 60,
                    onDecrease: { reps = max(1, reps - 1) },
                    onIncrease: { reps = min(60, reps + 1) },
                    onEdit: { onEditReps() }
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("主观强度 RPE")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(rpe.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.cobalt)
                        .contentTransition(.numericText())
                }
                .motionAnimation(Motion.quick, value: rpe)
                Slider(value: $rpe, in: 6...10, step: 0.5)
                    .tint(Theme.cobalt)
                    .sensoryFeedback(.selection, trigger: Int(rpe * 2))
                Text("6 = 很轻松 · 8 = 还能做 2 次 · 10 = 力竭")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if isLastSetCurrent {
                Button("撤销上一组") {
                    onUndoLast()
                }
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.coral)
            }
        }
        .card()
    }
}
