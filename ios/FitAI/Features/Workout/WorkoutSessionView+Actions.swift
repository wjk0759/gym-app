import SwiftUI

extension WorkoutSessionView {
    // MARK: - 行为

    func prepare(_ exercise: PlanExercise?) {
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

    func adjustWeight(by delta: Double) {
        let next = weight + delta
        weight = min(300, max(0, (next * 100).rounded() / 100))
    }

    func setSummary(for exercise: PlanExercise) -> String {
        let load = exercise.exercise?.equipment == .bodyweight
            ? "自重"
            : "\(WorkoutWeightFormat.text(weight)) kg"
        return "\(load) × \(reps) 次"
    }

    func completeSet(_ exercise: PlanExercise) {
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

    func advance() {
        restRemaining = nil
        if index < activeDay.exercises.count - 1 {
            index += 1
            prepare(currentExercise)
        } else {
            index = activeDay.exercises.count
        }
        saveDraftIfNeeded()
    }

    func tickRest() {
        guard let remaining = restRemaining else { return }
        if remaining <= 1 {
            restRemaining = nil
            Haptics.warning()
        } else {
            restRemaining = remaining - 1
        }
    }

    func loadDraftIfNeeded() {
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

    func saveDraftIfNeeded(persistImmediately: Bool = false) {
        guard !didFinish, !logs.isEmpty else { return }
        store.saveWorkoutDraft(
            WorkoutDraft(
                dayID: day.id,
                dayTitle: activeDay.title,
                logs: logs,
                currentIndex: index,
                plannedSets: plannedTotalSets,
                elapsedSeconds: currentElapsed,
                feeling: feeling,
                notes: String(notes.prefix(300)),
                adjustedExercises: Array(adjustedExercises.values),
                exercises: activeDay.exercises
            ),
            persistImmediately: persistImmediately
        )
    }

    func pauseAndExit() {
        saveDraftIfNeeded(persistImmediately: true)
        store.flushPersistence()
        dismiss()
    }

    func finish() {
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

    func openAdjustSheet(_ exercise: PlanExercise) {
        adjustExerciseID = exercise.id
        adjustSets = exercise.sets
        adjustReps = WorkoutPickerOptions.normalizedReps(exercise.reps)
        adjustWeight = exercise.weightKG ?? 0
        adjustRest = exercise.restSec
        showAdjustSheet = true
    }

    func saveAdjustedExercise() {
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

    var adjustSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SESSION / 调整")
                            .font(AppType.overline)
                            .tracking(1.2)
                            .foregroundStyle(Theme.cobalt)
                        Text(currentExercise?.displayName ?? "调整当前动作")
                            .font(AppType.title)
                            .foregroundStyle(Theme.ink)
                        Text("只调整这次训练的目标，不会改动长期计划。降低目标组数后会直接进入下一个动作。")
                            .font(AppType.caption)
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

                    Text("重量为 0 表示自重。")
                        .font(.system(size: 9.5, weight: .medium))
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
        .presentationBackground(Theme.background)
    }
}
