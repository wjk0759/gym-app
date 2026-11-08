import FitAIWorkoutCore
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

    var isWatchLed: Bool {
        WatchSyncManager.shared.hasActiveWatchSession(for: day.id)
    }

    var watchIsPaused: Bool {
        isWatchLed && WatchSyncManager.shared.isWatchSessionPaused
    }

    @discardableResult
    func sendToWatch(_ command: WorkoutCommand) -> Bool {
        if WatchSyncManager.shared.send(command: command) {
            return true
        }
        Haptics.warning()
        watchNotice = "手表未连接：本次训练以手表为准，请稍后再操作"
        return false
    }

    func completeSet(_ exercise: PlanExercise) {
        let nextIndex = completedSets(for: exercise) + 1
        let isBodyweight = exercise.exercise?.equipment == .bodyweight
        if isWatchLed {
            if watchIsPaused {
                watchNotice = "手表已暂停，请先在手表继续"
                return
            }
            let timed = exercise.reps.contains("秒")
            let command = WorkoutCommand.completeSet(
                .init(
                    exerciseID: exercise.id,
                    setIndex: nextIndex,
                    weightKG: isBodyweight ? 0 : weight,
                    reps: reps,
                    seconds: timed ? reps : nil,
                    rpe: rpe,
                    at: Date(),
                    source: .phone
                )
            )
            guard sendToWatch(command) else { return }
            Haptics.success()
            return
        }
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
        if isWatchLed {
            if watchIsPaused {
                watchNotice = "手表已暂停，请先在手表继续"
                return
            }
            let command = WorkoutCommand.advanceExercise(
                .init(at: Date(), source: .phone)
            )
            guard sendToWatch(command) else { return }
            return
        }
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

    /// The watch is authoritative during a watch-led session. Apply its
    /// snapshot to the phone UI and persist the draft before the phone leaves
    /// the foreground.
    func applyWatchSnapshot(_ envelope: WatchSessionEnvelope) {
        guard !didFinish,
              envelope.snapshot.programDayID == day.id else { return }
        let snapshot = envelope.snapshot
        guard snapshot.status != .discarded else {
            store.clearWorkoutDraft(dayID: day.id)
            didFinish = true
            dismiss()
            return
        }

        didLoadDraft = true
        logs = snapshot.sets.map { SetLog(record: $0) }
        index = min(snapshot.currentExerciseIndex, activeDay.exercises.count)
        elapsedSeconds = 0
        activeStartedAt = snapshot.startedAt
        if let remaining = snapshot.remainingRest(at: Date()), remaining > 0 {
            restTotal = max(1, remaining)
            restRemaining = max(0, Int(remaining.rounded()))
        } else {
            restRemaining = nil
        }
        saveDraftIfNeeded()
        if snapshot.status == .finished {
            finishFromWatch(snapshot)
        }
    }

    func syncWatchBootstrap() async {
        await store.refreshAccess()
        await WatchSyncManager.shared.prepareAndSendBootstrap(
            day: day,
            access: store.accessSnapshot,
            verifiedAt: store.access.verifiedAt,
            force: true
        )
    }

    func drainWatchInbox() {
        for envelope in WatchSyncManager.shared.pendingEnvelopes(for: day.id) {
            guard !didFinish else { break }
            applyWatchSnapshot(envelope)
            WatchSyncManager.shared.acknowledgeInbox(
                sessionID: envelope.sessionID,
                revision: envelope.snapshot.revision
            )
        }
    }

    /// The watch finished the session. Use its client session id so a later
    /// phone launch cannot record the same workout twice.
    func finishFromWatch(_ snapshot: WorkoutSessionSnapshot) {
        guard !logs.isEmpty else {
            store.clearWorkoutDraft(dayID: day.id)
            didFinish = true
            dismiss()
            return
        }
        didFinish = true
        var sessionDay = day
        sessionDay.exercises = activeDay.exercises.map(effectiveExercise)
        let end = snapshot.finishedAt ?? Date()
        let duration = max(
            1,
            Int(end.timeIntervalSince(snapshot.startedAt) / 60)
        )
        store.record(
            day: sessionDay,
            sets: logs,
            durationMinutes: duration,
            feeling: 3,
            notes: nil,
            plannedSets: snapshot.plannedSetCount,
            sessionID: snapshot.sessionID,
            endedAt: end,
            source: "watch"
        )
        store.clearWorkoutDraft(dayID: day.id)
        dismiss()
    }

    func pauseAndExit() {
        if isWatchLed {
            let command = WorkoutCommand.pause(
                .init(at: Date(), source: .phone)
            )
            guard sendToWatch(command) else { return }
        }
        saveDraftIfNeeded(persistImmediately: true)
        store.flushPersistence()
        dismiss()
    }

    func finish() {
        guard !logs.isEmpty else {
            showEmptySaveAlert = true
            return
        }
        if isWatchLed {
            let command = WorkoutCommand.finish(
                .init(at: Date(), source: .phone)
            )
            guard sendToWatch(command) else { return }
            watchNotice = "已通知手表结束，正在保存"
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
        if isWatchLed {
            watchNotice = "本次训练以手表为准，请在手表上调整"
            return
        }
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
