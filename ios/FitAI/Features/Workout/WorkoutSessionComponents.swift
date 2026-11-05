import SwiftUI

enum WorkoutWeightFormat {
    static func text(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        if (value * 10).rounded() == value * 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

struct WorkoutProgressHeader: View {
    let dayTitle: String
    let logsCount: Int
    let totalSets: Int
    let index: Int
    let exerciseCount: Int

    var body: some View {
        let progress = Double(logsCount) / Double(max(1, totalSets))

        return VStack(spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION / 训练进度")
                        .font(AppType.overline)
                        .tracking(1.2)
                        .foregroundStyle(Theme.cobalt)
                    Text(dayTitle)
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(logsCount)/\(totalSets) 组")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("\(min(index + 1, exerciseCount))/\(exerciseCount) 动作")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .contentTransition(.numericText())
                }
            }

            ProgressView(value: min(1, progress))
                .tint(Theme.cobalt)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .motionAnimation(Motion.smooth, value: progress)
        }
        .motionAnimation(Motion.quick, value: logsCount)
        .motionAnimation(Motion.quick, value: index)
        .appPagePadding()
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }
}

struct WorkoutSessionExerciseCard: View {
    let exercise: PlanExercise
    let index: Int
    let exerciseCount: Int
    let periodMode: PeriodTrainingMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("动作 \(index + 1)/\(exerciseCount)")
                    .font(AppType.overline)
                    .tracking(1.1)
                    .foregroundStyle(Theme.cobalt)

                Spacer(minLength: 4)

                if let equipment = exercise.exercise?.equipment {
                    Text(equipment.label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Text(exercise.displayName)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(exercise.targetText)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary, in: Capsule(style: .continuous))

                if periodMode == .light {
                    Text("经期轻量")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cycle)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.cycle.opacity(0.10), in: Capsule(style: .continuous))
                }

                Spacer(minLength: 0)
            }

            if periodMode == .light {
                Text("自动少 1 组、负重约 80%。腹痛明显时请改为散步或休息。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cycle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let instructions = exercise.exercise?.instructions {
                Text(instructions)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.lime)
    }
}

struct WorkoutTrainingTipCard: View {
    let exercise: PlanExercise
    let lastSet: SetLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("教练提示")
                    .font(AppType.overline)
                    .tracking(0.9)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Text("目标 RPE \(exercise.rpe, specifier: "%.1f")")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("保留 1–2 次余力；动作变形就降重量。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let lastSet {
                Text("上次：\(lastSet.weightKG > 0 ? String(format: "%.1f kg", lastSet.weightKG) : "自重") × \(lastSet.reps) 次")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card(padding: 14)
    }
}

struct WorkoutRestCard: View {
    let remaining: Int
    let total: Double
    let onSkip: () -> Void

    var body: some View {
        let progress = CGFloat(min(1, max(0, Double(remaining) / max(1, total))))
        let urgent = remaining <= 5

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.stroke, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        urgent ? Theme.secondary : Theme.primary,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)
            .animation(Motion.quick, value: urgent)

            VStack(alignment: .leading, spacing: 3) {
                Text("组间休息")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(urgent ? "马上开始下一组" : "呼吸放松，保持动作质量")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(urgent ? Theme.secondary : Theme.secondaryText)
            }

            Spacer(minLength: 4)

            Button("跳过") {
                Haptics.tap()
                onSkip()
            }
            .font(AppType.caption.weight(.semibold))
            .foregroundStyle(Theme.cobalt)
            .buttonStyle(SubtlePressStyle())
        }
        .padding(14)
        .background(
            Theme.cobalt.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.cobalt.opacity(0.18), lineWidth: 1)
        }
    }
}

struct WorkoutSessionActionBar: View {
    let exercise: PlanExercise?
    let done: Int
    let nextTitle: String
    let setSummary: String
    let onSkip: () -> Void
    let onComplete: () -> Void
    let onAdvance: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let exercise {
                HStack {
                    Button("跳过这个动作") {
                        onSkip()
                    }
                    .font(AppType.caption.weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)

                    Spacer()

                    if done > 0 {
                        Text("已完成 \(done) 组")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                    }
                }

                if done < exercise.sets {
                    Button {
                        onComplete()
                    } label: {
                        Text("完成第 \(done + 1) 组 · \(setSummary)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("完成第 \(done + 1) 组，\(setSummary)")
                } else {
                    Button(nextTitle) {
                        onAdvance()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("保存并结束") {
                    onFinish()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .appPagePadding()
        .padding(.top, AppLayout.actionBarSpacing)
        .padding(.bottom, 8)
        .background(Theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }
}

struct WorkoutWeightStepPicker: View {
    @Binding var weightStep: Double

    var body: some View {
        HStack(spacing: 6) {
            Text("每次调整")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)

            ForEach([1.25, 2.5, 5.0], id: \.self) { step in
                Button {
                    Haptics.select()
                    weightStep = step
                } label: {
                    Text("\(WorkoutWeightFormat.text(step)) kg")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(weightStep == step ? Theme.paper : Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(
                            Capsule(style: .continuous)
                                .fill(weightStep == step ? Theme.ink : Theme.paper)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    weightStep == step ? Theme.ink : Theme.stroke,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))
                .accessibilityLabel("每次调整 \(WorkoutWeightFormat.text(step)) 千克")
                .accessibilityAddTraits(weightStep == step ? .isSelected : [])
            }

            Spacer(minLength: 0)
        }
        .motionAnimation(Motion.quick, value: weightStep)
    }
}



struct WorkoutSessionSummaryCard: View {
    let logs: [SetLog]
    let plannedTotalSets: Int
    let isFullSession: Bool
    let durationMinutes: Int
    @Binding var feeling: Int
    @Binding var notes: String

    var body: some View {
VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SESSION / 总结")
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Text(isFullSession ? "训练完成" : "本次训练记录")
                    .font(AppType.hero)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
            }

            if !isFullSession {
                Text("已完成 \(logs.count)/\(plannedTotalSets) 组；保存后日历只记录这些完成组，不会算成整个训练日。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(
                        Theme.coral.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Theme.coral.opacity(0.20), lineWidth: 1)
                    }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    summaryMetric("\(logs.count)", "完成组数")
                    summaryMetric("\(Int(logs.reduce(0.0) { $0 + $1.weightKG * Double($1.reps) }))", "总容量 kg")
                    summaryMetric("\(durationMinutes)", "分钟")
                }

                VStack(spacing: 8) {
                    summaryMetric("\(logs.count)", "完成组数")
                    summaryMetric("\(Int(logs.reduce(0.0) { $0 + $1.weightKG * Double($1.reps) }))", "总容量 kg")
                    summaryMetric("\(durationMinutes)", "分钟")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("今天感觉如何？")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            Haptics.select()
                            withAnimation(Motion.bouncy) {
                                feeling = value
                            }
                        } label: {
                            Text(WorkoutFeeling.emoji(value))
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(feeling == value ? Theme.ink : Theme.paper)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(
                                            feeling == value ? Theme.ink : Theme.stroke,
                                            lineWidth: 1
                                        )
                                )
                                .scaleEffect(feeling == value ? 1.05 : 1)
                                .animation(Motion.quick, value: feeling)
                        }
                        .buttonStyle(SubtlePressStyle(scale: 0.94))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("训练心得（可选）")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(notes.count)/300")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                TextField("今天状态、动作感受、下次注意什么…", text: $notes, axis: .vertical)
                    .font(AppType.callout)
                    .lineLimit(2...5)
                    .padding(11)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
                    .onChange(of: notes) { _, value in
                        if value.count > 300 {
                            notes = String(value.prefix(300))
                        }
                    }
            }

            Text("记录会用于下一次计划调整。至少完成一组再保存，AI 才能判断负荷。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: Theme.lime)
    }

    private func summaryMetric(_ value: String, _ title: String) -> some View {
VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .motionAnimation(Motion.quick, value: value)
    }
}

enum WorkoutValueEditor: String, Identifiable {
    case weight
    case reps

    var id: String { rawValue }
}

struct WorkoutSessionValueEntrySheet: View {
    let editor: WorkoutValueEditor
    @Binding var weight: Double
    @Binding var reps: Int

    var body: some View {
        switch editor {
        case .weight:
            WorkoutValueEntrySheet(
                title: "本组重量",
                unit: "kg",
                footnote: "本组实际重量；0 表示自重。",
                allowsDecimal: true,
                range: 0...300
            ) { value in
                weight = min(300, max(0, value))
            }
        case .reps:
            WorkoutValueEntrySheet(
                title: "实际次数",
                unit: "次",
                footnote: "当前 \(reps) 次。输入本组实际完成的次数，即使少于目标次数也按实际记录。",
                allowsDecimal: false,
                range: 1...60
            ) { value in
                reps = min(60, max(1, Int(value.rounded())))
            }
        }
    }
}
