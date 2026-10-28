import Combine
import SwiftUI
import UIKit

struct WorkoutSessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let day: PlanDay
    let periodMode: PeriodTrainingMode?

    init(day: PlanDay, periodMode: PeriodTrainingMode? = nil) {
        self.day = day
        self.periodMode = periodMode
    }

    @State private var index = 0
    @State private var logs: [SetLog] = []
    @State private var weight: Double = 0
    @State private var reps: Int = 10
    @State private var rpe: Double = 7.5
    @State private var restRemaining: Int?
    @State private var restTotal: Double = 1
    @State private var feeling = 4
    @State private var notes = ""
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var resumedExercises: [PlanExercise]?
    @State private var didLoadDraft = false
    @State private var didFinish = false
    @State private var showResumeBanner = false
    @State private var showExitConfirm = false
    @State private var showEmptySaveAlert = false
    @State private var adjustedExercises: [UUID: PlanExercise] = [:]
    @State private var showAdjustSheet = false
    @State private var adjustExerciseID: UUID?
    @State private var adjustSets = 3
    @State private var adjustReps = "10-12"
    @State private var adjustWeight = 0.0
    @State private var adjustRest = 60
    @State private var weightStep = 2.5
    @State private var valueEditor: ValueEditor?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private enum ValueEditor: String, Identifiable {
        case weight
        case reps

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                if showResumeBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("已恢复上次进度：\(logs.count) 组")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 4)
                        Button("知道了") {
                            withAnimation(Motion.quick) {
                                showResumeBanner = false
                            }
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Theme.accent.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
                    )
                    .appPagePadding()
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                ScrollViewReader { proxy in
                    AppScrollView {
                        VStack(spacing: AppLayout.sectionSpacing) {
                            if let restRemaining {
                                restCard(restRemaining)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            Group {
                                if let exercise = currentExercise {
                                    exerciseCard(exercise)
                                    setCard(exercise)
                                    trainingTipCard(exercise)
                                } else {
                                    summaryCard
                                }
                            }
                            .id(index)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .offset(x: 22)),
                                    removal: .opacity.combined(with: .offset(x: -18))
                                )
                            )
                        }
                        .appPagePadding()
                        .padding(.vertical, 16)
                        .padding(.bottom, 24)
                        .appReadableContent()
                        .id("session-top")
                        .motionAnimation(Motion.smooth, value: index)
                        .motionAnimation(Motion.quick, value: restRemaining != nil)
                    }
                    .onChange(of: index) { _, _ in
                        withAnimation(Motion.smooth) {
                            proxy.scrollTo("session-top", anchor: .top)
                        }
                    }
                    .onChange(of: restRemaining != nil) { _, isResting in
                        guard isResting else { return }
                        withAnimation(Motion.smooth) {
                            proxy.scrollTo("session-top", anchor: .top)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                workoutActionBar
            }
            .background(AppBackground())
            .navigationTitle("训练中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentExercise != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("暂停") { showExitConfirm = true }
                    }
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                loadDraftIfNeeded()
                prepare(currentExercise)
            }
            .onDisappear {
                saveDraftIfNeeded(persistImmediately: true)
                store.flushPersistence()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                saveDraftIfNeeded(persistImmediately: true)
                store.flushPersistence()
            }
            .onReceive(timer) { _ in
                tickRest()
                tickElapsed()
            }
            .confirmationDialog(
                "暂停或结束训练？",
                isPresented: $showExitConfirm,
                titleVisibility: .visible
            ) {
                Button("暂停，稍后继续") { pauseAndExit() }
                Button("结束并保存", role: .destructive) { finish() }
                Button("继续训练", role: .cancel) {}
            } message: {
                Text("暂停会保存已完成的 \(logs.count) 组，下次进来接着练；结束并保存会生成训练记录。")
            }
            .alert("还没有训练记录", isPresented: $showEmptySaveAlert) {
                Button("继续训练", role: .cancel) {}
                Button("放弃并退出", role: .destructive) {
                    store.clearWorkoutDraft(dayID: day.id)
                    didFinish = true
                    dismiss()
                }
            } message: {
                Text("至少完成一组后再保存，避免产生一条 0 组的空训练记录。")
            }
            .sheet(isPresented: $showAdjustSheet) {
                adjustSheet
            }
            .sheet(item: $valueEditor) { editor in
                valueEntrySheet(editor)
            }
        }
    }

    // MARK: - 顶部进度

    private var progressHeader: some View {
        let totalSets = plannedTotalSets
        let progress = Double(logs.count) / Double(max(1, totalSets))

        return VStack(spacing: 8) {
            HStack {
                Text("\(logs.count)/\(totalSets) 组")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
                    .contentTransition(.numericText())
                Spacer()
                Text("\(min(index + 1, activeDay.exercises.count))/\(activeDay.exercises.count) 动作")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.tertiaryText)
                    .contentTransition(.numericText())
            }
            ProgressView(value: min(1, progress))
                .tint(Theme.accent)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .motionAnimation(Motion.smooth, value: progress)
        }
        .motionAnimation(Motion.quick, value: logs.count)
        .motionAnimation(Motion.quick, value: index)
        .appPagePadding()
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    // MARK: - 当前动作

    private var currentExercise: PlanExercise? {
        guard activeDay.exercises.indices.contains(index) else { return nil }
        return effectiveExercise(activeDay.exercises[index])
    }

    /// 恢复草稿时使用草稿里的动作列表，避免用户自定义过的训练顺序被计划原顺序覆盖。
    private var activeDay: PlanDay {
        var value = day
        if let resumedExercises {
            value.exercises = resumedExercises
        }
        return value
    }

    private var plannedTotalSets: Int {
        activeDay.exercises.reduce(0) { partial, exercise in
            partial + max(1, effectiveExercise(exercise).sets)
        }
    }

    private func effectiveExercise(_ exercise: PlanExercise) -> PlanExercise {
        var value = adjustedExercises[exercise.id] ?? exercise
        if periodMode == .light {
            value.sets = max(2, value.sets - 1)
            if let weight = value.weightKG, weight > 0 {
                value.weightKG = ((weight * 0.8) * 2).rounded() / 2
            }
        }
        return value
    }

    private func completedSets(for exercise: PlanExercise) -> Int {
        logs.filter { $0.slug == exercise.slug }.count
    }

    private func exerciseCard(_ exercise: PlanExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("动作 \(index + 1)/\(activeDay.exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if let equipment = exercise.exercise?.equipment {
                    Text(equipment.label)
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Text(exercise.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(exercise.targetText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)

            if periodMode == .light {
                Text("经期轻量版：自动少 1 组、负重约 80%。腹痛明显时请改为散步或休息。")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let instructions = exercise.exercise?.instructions {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func setCard(_ exercise: PlanExercise) -> some View {
        let done = completedSets(for: exercise)
        let isBodyweight = exercise.exercise?.equipment == .bodyweight

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("第 \(min(done + 1, exercise.sets)) 组 / 共 \(exercise.sets) 组")
                    .font(.headline)
                Spacer(minLength: 4)
                Text("目标 RPE \(exercise.rpe, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button {
                    openAdjustSheet(exercise)
                } label: {
                    Text("调整")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(
                            Theme.accent.opacity(0.12),
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))
                .accessibilityHint("调整目标组数、次数、重量和休息")
            }

            if let last = store.lastSet(for: exercise.slug) {
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(SubtlePressStyle())
                    .accessibilityLabel("使用上次的重量和次数")
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            }

            if let best = store.bestSet(for: exercise.slug) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Theme.warning)
                    Text("历史最佳 \(best.weightKG > 0 ? "\(best.weightKG.formatted()) kg × \(best.reps)" : "自重 × \(best.reps)")")
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("本组数据")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Text("点数字输入 · 长按连续调")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if !isBodyweight {
                    ValueStepperControl(
                        title: "本组重量",
                        value: weightText(weight),
                        unit: "kg",
                        hint: "步进 \(weightStepText(weightStep)) kg",
                        canDecrease: weight > 0,
                        canIncrease: weight < 300,
                        onDecrease: { adjustWeight(by: -weightStep) },
                        onIncrease: { adjustWeight(by: weightStep) },
                        onEdit: { valueEditor = .weight }
                    )

                    weightStepPicker
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.strengthtraining.functional")
                        Text("自重动作，直接填写本组实际次数")
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(
                        Theme.surfaceStrong,
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
                    onEdit: { valueEditor = .reps }
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("主观强度 RPE")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(rpe.formatted(.number.precision(.fractionLength(1))))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                }
                .motionAnimation(Motion.quick, value: rpe)
                Slider(value: $rpe, in: 6...10, step: 0.5)
                    .tint(Theme.accent)
                    .sensoryFeedback(.selection, trigger: Int(rpe * 2))
                Text("6 = 很轻松 · 8 = 还能做 2 次 · 10 = 力竭")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if done > 0,
               let last = logs.last,
               last.slug == exercise.slug {
                Button("撤销上一组") {
                    logs.removeLast()
                    restRemaining = nil
                }
                .font(.caption)
                .foregroundStyle(Theme.warning)
            }
        }
        .card()
    }

    private var weightStepPicker: some View {
        HStack(spacing: 6) {
            Text("每次调整")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)

            ForEach([1.25, 2.5, 5.0], id: \.self) { step in
                Button {
                    Haptics.select()
                    weightStep = step
                } label: {
                    Text("\(weightStepText(step)) kg")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(weightStep == step ? Color.black.opacity(0.9) : Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(
                            Capsule(style: .continuous)
                                .fill(weightStep == step ? Theme.accent : Theme.surfaceStrong)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    weightStep == step ? Color.clear : Color.white.opacity(0.07),
                                    lineWidth: 0.8
                                )
                        )
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))
                .accessibilityLabel("每次调整 \(weightStepText(step)) 千克")
                .accessibilityAddTraits(weightStep == step ? .isSelected : [])
            }

            Spacer(minLength: 0)
        }
        .motionAnimation(Motion.quick, value: weightStep)
    }

    private func trainingTipCard(_ exercise: PlanExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("训练提示")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("目标 RPE \(exercise.rpe, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("保留 1–2 次余力，组间休息 \(exercise.restSec) 秒；动作变形就降重量，不要为了完成次数牺牲动作质量。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let last = store.lastSet(for: exercise.slug) {
                Text("上次：\(last.weightKG > 0 ? String(format: "%.1f kg", last.weightKG) : "自重") × \(last.reps) 次")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card(padding: 14)
    }

    private var workoutActionBar: some View {
        VStack(spacing: 8) {
            if let exercise = currentExercise {
                let done = completedSets(for: exercise)

                HStack {
                    Button("跳过这个动作") {
                        advance()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)

                    Spacer()

                    if done > 0 {
                        Text("已完成 \(done) 组")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }

                if done < exercise.sets {
                    Button {
                        completeSet(exercise)
                    } label: {
                        Text("完成第 \(done + 1) 组 · \(setSummary(for: exercise))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityLabel("完成第 \(done + 1) 组，\(setSummary(for: exercise))")
                } else {
                    Button(nextTitle) {
                        advance()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("保存并结束") {
                    finish()
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

    private var nextTitle: String {
        index < activeDay.exercises.count - 1 ? "下一个动作" : "查看训练总结"
    }

    private func restCard(_ remaining: Int) -> some View {
        let total = max(1, restTotal)
        let progress = CGFloat(min(1, max(0, Double(remaining) / total)))
        let urgent = remaining <= 5

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.stroke, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        urgent ? Theme.warning : Theme.accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                Text("\(remaining)")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)
            .animation(Motion.quick, value: urgent)

            VStack(alignment: .leading, spacing: 3) {
                Text("组间休息")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(urgent ? "马上开始下一组" : "呼吸放松，保持动作质量")
                    .font(.caption2)
                    .foregroundStyle(urgent ? Theme.warning : Theme.secondaryText)
            }

            Spacer(minLength: 4)

            Button("跳过") {
                Haptics.tap()
                restRemaining = nil
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .buttonStyle(SubtlePressStyle())
        }
        .card(padding: 14)
    }

    // MARK: - 总结

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isFullSession ? "训练完成" : "本次训练记录")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            if !isFullSession {
                Text("已完成 \(logs.count)/\(plannedTotalSets) 组；保存后日历只记录这些完成组，不会算成整个训练日。")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
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
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            Haptics.select()
                            withAnimation(Motion.bouncy) {
                                feeling = value
                            }
                        } label: {
                            Text(feelingEmoji(value))
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(feeling == value ? Theme.accent.opacity(0.18) : Theme.surfaceStrong)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(
                                            feeling == value ? Theme.accent.opacity(0.55) : Color.clear,
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(notes.count)/300")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                TextField("今天状态、动作感受、下次注意什么…", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(11)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .onChange(of: notes) { _, value in
                        if value.count > 300 {
                            notes = String(value.prefix(300))
                        }
                    }
            }

            Text("记录会用于下一次计划调整。至少完成一组再保存，AI 才能判断负荷。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func summaryMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .motionAnimation(Motion.quick, value: value)
    }

    private var isFullSession: Bool {
        let completed = store.finalizedCompletedSets(for: day) + logs.filter(\.completed).count
        return completed >= plannedTotalSets
    }

    private var durationMinutes: Int {
        max(1, Int(elapsedSeconds / 60))
    }

    // MARK: - 行为

    private func prepare(_ exercise: PlanExercise?) {
        guard let exercise else { return }
        weight = exercise.weightKG ?? 0
        let firstComponent = exercise.reps.components(separatedBy: "-").first ?? ""
        let digits = firstComponent.filter { $0.isNumber }
        reps = Int(digits) ?? 10
        rpe = exercise.rpe

        if let last = logs.last(where: { $0.slug == exercise.slug && $0.completed }) {
            weight = last.weightKG
            reps = last.reps
        } else if let last = store.lastSet(for: exercise.slug) {
            weight = last.weightKG
            reps = last.reps
        }
    }

    private func adjustWeight(by delta: Double) {
        let next = weight + delta
        weight = min(300, max(0, (next * 100).rounded() / 100))
    }

    private func weightText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        if (value * 10).rounded() == value * 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private func weightStepText(_ value: Double) -> String {
        weightText(value)
    }

    private func setSummary(for exercise: PlanExercise) -> String {
        let load = exercise.exercise?.equipment == .bodyweight
            ? "自重"
            : "\(weightText(weight)) kg"
        return "\(load) × \(reps) 次"
    }

    @ViewBuilder
    private func valueEntrySheet(_ editor: ValueEditor) -> some View {
        switch editor {
        case .weight:
            WorkoutValueEntrySheet(
                title: "本组重量",
                unit: "kg",
                footnote: "当前 \(weightText(weight)) kg。输入本组实际使用的重量，保存后完成这一组会按这个重量记录。",
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

    private func completeSet(_ exercise: PlanExercise) {
        let nextIndex = completedSets(for: exercise) + 1
        let isBodyweight = exercise.exercise?.equipment == .bodyweight
        logs.append(
            SetLog(
                slug: exercise.slug,
                setIndex: nextIndex,
                weightKG: isBodyweight ? 0 : weight,
                reps: reps,
                rpe: rpe
            )
        )
        Haptics.success()
        saveDraftIfNeeded()
        let rest = exercise.restSec
        restTotal = Double(max(1, rest))
        restRemaining = rest > 0 ? rest : nil
    }

    private func advance() {
        restRemaining = nil
        if index < activeDay.exercises.count - 1 {
            index += 1
            prepare(currentExercise)
        } else {
            index = activeDay.exercises.count
        }
        saveDraftIfNeeded()
    }

    private func tickRest() {
        guard let remaining = restRemaining else { return }
        if remaining <= 1 {
            restRemaining = nil
            Haptics.warning()
        } else {
            restRemaining = remaining - 1
        }
    }

    private func tickElapsed() {
        guard !didFinish, index < activeDay.exercises.count else { return }
        elapsedSeconds += 1
    }

    private func loadDraftIfNeeded() {
        guard !didLoadDraft else { return }
        didLoadDraft = true
        guard let draft = store.draft(for: day.id) else { return }

        logs = draft.logs
        if let exercises = draft.exercises, !exercises.isEmpty {
            resumedExercises = exercises
        }
        let draftExerciseCount = draft.exercises?.count ?? 0
        let exerciseCount = draftExerciseCount > 0 ? draftExerciseCount : day.exercises.count
        index = min(max(0, draft.currentIndex), exerciseCount)
        elapsedSeconds = max(0, draft.elapsedSeconds)
        feeling = draft.feeling
        notes = draft.notes
        adjustedExercises = Dictionary(
            draft.adjustedExercises.map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        guard !draft.logs.isEmpty else { return }
        withAnimation(Motion.smooth) {
            showResumeBanner = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(Motion.quick) {
                showResumeBanner = false
            }
        }
    }

    private func saveDraftIfNeeded(persistImmediately: Bool = false) {
        guard !didFinish, !logs.isEmpty else { return }
        store.saveWorkoutDraft(
            WorkoutDraft(
                dayID: day.id,
                dayTitle: activeDay.title,
                logs: logs,
                currentIndex: index,
                plannedSets: plannedTotalSets,
                elapsedSeconds: elapsedSeconds,
                feeling: feeling,
                notes: String(notes.prefix(300)),
                adjustedExercises: Array(adjustedExercises.values),
                exercises: activeDay.exercises
            ),
            persistImmediately: persistImmediately
        )
    }

    private func pauseAndExit() {
        saveDraftIfNeeded(persistImmediately: true)
        store.flushPersistence()
        dismiss()
    }

    private func finish() {
        guard !logs.isEmpty else {
            showEmptySaveAlert = true
            return
        }
        didFinish = true
        var sessionDay = day
        sessionDay.exercises = activeDay.exercises.map(effectiveExercise)
        let planned = plannedTotalSets
        store.record(
            day: sessionDay,
            sets: logs,
            durationMinutes: durationMinutes,
            feeling: feeling,
            notes: String(notes.prefix(300)),
            plannedSets: planned
        )
        store.clearWorkoutDraft(dayID: day.id)
        dismiss()
    }

    private func openAdjustSheet(_ exercise: PlanExercise) {
        adjustExerciseID = exercise.id
        adjustSets = exercise.sets
        adjustReps = WorkoutPickerOptions.normalizedReps(exercise.reps)
        adjustWeight = exercise.weightKG ?? 0
        adjustRest = exercise.restSec
        showAdjustSheet = true
    }

    private func saveAdjustedExercise() {
        guard
            let id = adjustExerciseID,
            let base = activeDay.exercises.first(where: { $0.id == id })
        else {
            showAdjustSheet = false
            return
        }

        var updated = base
        updated.sets = min(max(adjustSets, 1), 10)
        updated.reps = WorkoutPickerOptions.normalizedReps(adjustReps)
        updated.weightKG = adjustWeight > 0 ? adjustWeight : nil
        updated.restSec = min(max(adjustRest, 0), 300)
        adjustedExercises[id] = updated

        if currentExercise?.id == id {
            weight = updated.weightKG ?? 0
            if let parsed = Int(updated.reps.filter(\.isNumber)) {
                reps = parsed
            }
        }

        saveDraftIfNeeded()
        showAdjustSheet = false
        Haptics.success()
    }

    private var adjustSheet: some View {
        let doneCount = currentExercise.map { completedSets(for: $0) } ?? 0

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("本次训练")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(currentExercise?.displayName ?? "调整当前动作")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("只调整这次训练的目标，不会改动长期计划。降低目标组数后会直接进入下一个动作。")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 9) {
                        WheelPickerField(
                            title: "目标组数 · 组",
                            selection: $adjustSets,
                            options: WorkoutPickerOptions.sets,
                            display: { "\($0)" }
                        )
                        WheelPickerField(
                            title: "每组次数 · 次",
                            selection: $adjustReps,
                            options: WorkoutPickerOptions.reps,
                            display: { $0 }
                        )
                        WeightInputField(
                            title: "目标重量",
                            weight: $adjustWeight
                        )
                        WheelPickerField(
                            title: "组间休息 · 秒",
                            selection: $adjustRest,
                            options: WorkoutPickerOptions.rests(including: adjustRest),
                            display: { "\($0)" }
                        )
                    }

                    Text("重量为 0 表示自重；已完成 \(doneCount) 组。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)

                    Button("保存调整") {
                        saveAdjustedExercise()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 3)
                }
                .appPagePadding()
                .padding(.vertical, 18)
                .appReadableContent()
            }
            .background(AppBackground())
            .navigationTitle("调整本次训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAdjustSheet = false }
                }
            }
            .keyboardDoneToolbar()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }



    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "💪"
        }
    }
}
