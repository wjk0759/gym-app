import Foundation

extension AppStore {
    func lastSet(for slug: String) -> SetLog? {
        for session in sessions {
            if let set = session.sets.last(where: { $0.slug == slug && $0.completed }) {
                return set
            }
        }
        return nil
    }

    /// 历史最佳组：先比较重量，再比较次数；自重动作按次数比较。
    func bestSet(for slug: String) -> SetLog? {
        sessions
            .flatMap(\.sets)
            .filter { $0.slug == slug && $0.completed }
            .max { left, right in
                if left.weightKG != right.weightKG {
                    return left.weightKG < right.weightKG
                }
                return left.reps < right.reps
            }
    }

    func updateDay(_ day: PlanDay) {
        guard var current = plan,
              let index = current.days.firstIndex(where: { $0.id == day.id }) else {
            return
        }
        current.days[index] = day
        plan = current
        persist()
    }

    func addExercise(_ exercise: Exercise, to dayID: UUID) {
        guard var current = plan,
              let dayIndex = current.days.firstIndex(where: { $0.id == dayID }) else {
            return
        }
        let params = current.days[dayIndex].exercises.first
        let item = PlanExercise(
            slug: exercise.slug,
            sets: params?.sets ?? 3,
            reps: params?.reps ?? "10-12",
            weightKG: nil,
            restSec: params?.restSec ?? 60,
            rpe: 7
        )
        dislikedSlugs.remove(exercise.slug)
        current.days[dayIndex].exercises.append(item)
        plan = current
        persist()
    }

    func clearPreferences() {
        dislikedSlugs.removeAll()
        persist()
    }

    // MARK: - 训练与对话

    func record(
        day: PlanDay,
        sets: [SetLog],
        durationMinutes: Int,
        feeling: Int,
        notes: String? = nil,
        plannedSets: Int? = nil,
        sessionID: UUID? = nil,
        endedAt: Date? = nil
    ) {
        let cleanNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = WorkoutSession(
            id: sessionID ?? UUID(),
            date: endedAt ?? Date(),
            dayTitle: day.title,
            durationMinutes: durationMinutes,
            feeling: feeling,
            notes: (cleanNotes?.isEmpty ?? true) ? nil : cleanNotes,
            sets: sets,
            programDayID: day.id.uuidString,
            plannedSets: plannedSets
        )
        if workoutDraft?.dayID == day.id {
            workoutDraft = nil
        }
        sessions.insert(session, at: 0)
        persist()
        syncPendingWorkouts()

        if healthKitEnabled {
            let end = endedAt ?? Date()
            let start = end.addingTimeInterval(-Double(durationMinutes * 60))
            Task {
                try? await HealthKitService.shared.saveStrengthWorkout(
                    start: start,
                    end: end
                )
            }
        }
    }

    func addSession(_ session: WorkoutSession) {
        sessions.insert(session, at: 0)
        persist()
        syncPendingWorkouts()
    }

    // MARK: - 训练草稿

    func draft(for dayID: UUID) -> WorkoutDraft? {
        guard let workoutDraft, workoutDraft.dayID == dayID else { return nil }
        return workoutDraft
    }

    /// 当前草稿对应的计划日；计划已重新生成时可能找不到。
    var draftPlanDay: PlanDay? {
        guard let draft = workoutDraft, let plan else { return nil }
        return plan.days.first { $0.id == draft.dayID }
    }

    func saveWorkoutDraft(_ draft: WorkoutDraft, persistImmediately: Bool = false) {
        let isNewDraft = workoutDraft?.dayID != draft.dayID
        workoutDraft = draft

        if persistImmediately || isNewDraft {
            draftPersistWorkItem?.cancel()
            draftPersistWorkItem = nil
            persist()
            return
        }

        // 训练中每完成一组就全量编码落盘会放大 I/O。首次保存立即落盘，
        // 后续最多每 10 秒合并一次；暂停/切后台/退出时再强制落盘。
        guard draftPersistWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.draftPersistWorkItem = nil
            self.persist()
        }
        draftPersistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    func clearWorkoutDraft(dayID: UUID? = nil) {
        if let dayID {
            guard workoutDraft?.dayID == dayID else { return }
        }
        workoutDraft = nil
        persist()
    }

    func updateSession(_ session: WorkoutSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }
        var updated = session
        if updated.remoteID != nil {
            updated.pendingRemoteUpdate = true
        }
        sessions[index] = updated
        persist()
        syncPendingWorkouts()
    }
}
