import Foundation

extension AppStore {
    // MARK: - App Action 执行层

    func agentAppContext() -> [String: Any] {
        var context: [String: Any] = [
            "today": FitnessDate.key(Date()),
            "selected_tab": selectedTab,
        ]
        if let visual = coachVisualMemory {
            context["visual_context"] = [
                "summary": visual.summary,
                "observations": visual.observations,
                "mode": visual.mode,
                "image_count": visual.imageCount,
                "last_question": visual.lastQuestion,
                "updated_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: visual.updatedAt),
            ]
        }
        guard let plan else { return context }
        let days: [[String: Any]] = plan.days.map { day in
            let date = plan.scheduledDate(for: day)
            return [
                "id": day.id.uuidString,
                "title": day.title,
                "date": date.map { FitnessDate.key($0) } ?? "",
                "week_index": day.weekIndex,
                "completed": isPlanDayCompleted(day),
                "in_progress": !isPlanDayCompleted(day) && workoutDraft?.dayID == day.id,
                "progress": planDayProgress(day),
                "planned_sets": plannedSets(for: day),
                "completed_sets": completedSets(for: day),
                "exercises": day.exercises.map { item -> [String: Any] in
                    [
                        "slug": item.slug,
                        "sets": item.sets,
                        "reps": item.reps,
                        "weight_kg": item.weightKG ?? 0,
                        "rest_sec": item.restSec,
                    ]
                },
                "skipped": day.skippedAt != nil,
            ]
        }
        context["plan"] = [
            "id": plan.id.uuidString,
            "title": plan.title,
            "weeks": plan.weeks,
            "weekly_days": plan.weeklyDays ?? profile.weeklyDays,
            "days": days,
        ]
        if let today = todayDay, let date = plan.scheduledDate(for: today) {
            context["today_day"] = [
                "id": today.id.uuidString,
                "title": today.title,
                "date": FitnessDate.key(date),
                "completed": isPlanDayCompleted(today),
                "in_progress": !isPlanDayCompleted(today) && workoutDraft?.dayID == today.id,
                "progress": planDayProgress(today),
                "completed_sets": completedSets(for: today),
                "planned_sets": plannedSets(for: today),
            ]
        }
        return context
    }

    func executeAgentActions() {
        guard !agentActions.isEmpty, !isExecutingAgentActions else { return }
        let actions = agentActions
        let runID = agentRunID
        agentActions = []
        pendingUndo = nil
        isExecutingAgentActions = true
        persist()
        Task { @MainActor in
            defer {
                self.isExecutingAgentActions = false
                self.persist()
            }
            var results: [String] = []
            var undoStates: [AgentUndoState] = []
            for action in actions {
                var undoState: AgentUndoState?
                let message = self.executeAgentAction(action, undo: &undoState)
                results.append(message)
                let status = self.agentActionStatus(for: message)
                if status != "failed", let undoState {
                    undoStates.append(undoState)
                }
                Task {
                    try? await APIClient.shared.reportAgentAction(
                        id: action.id,
                        runID: runID,
                        type: action.type,
                        status: status,
                        message: message
                    )
                }
            }
            if !undoStates.isEmpty, let first = actions.first {
                self.pendingUndo = AgentUndoAction(
                    id: first.id,
                    title: undoStates.count == 1 ? first.title : "恢复本次 \(undoStates.count) 项修改",
                    actionType: undoStates.count == 1 ? first.type : "batch",
                    expiresAt: Date().addingTimeInterval(300),
                    runID: runID,
                    state: undoStates.count == 1 ? undoStates[0] : .batch(undoStates)
                )
            }
            self.chat.append(
                ChatMessage(
                    role: .assistant,
                    text: "已为你完成：\n" + results.joined(separator: "\n")
                )
            )
            self.toast = "Agent 操作已执行"
        }
    }

    func dismissAgentActions() {
        let actions = agentActions
        let runID = agentRunID
        agentActions = []
        for action in actions {
            Task {
                try? await APIClient.shared.reportAgentAction(
                    id: action.id,
                    runID: runID,
                    type: action.type,
                    status: "rejected",
                    message: "用户取消"
                )
            }
        }
        persist()
    }

    private func agentActionStatus(for message: String) -> String {
        if message.hasPrefix("没有")
            || message.hasPrefix("暂不支持")
            || message.contains("失败")
            || message.contains("为空")
        {
            return "failed"
        }
        return "executed"
    }

    private func executeAgentAction(
        _ action: AgentAction,
        undo: inout AgentUndoState?
    ) -> String {
        switch action.type {
        case "open_screen":
            guard let screen = action.payload?.screen else {
                return "没有指定要打开的页面"
            }
            switch screen {
            case "today": selectedTab = 0
            case "plan": selectedTab = 1
            case "coach": selectedTab = 2
            case "equipment": selectedTab = 3
            case "profile": selectedTab = 4
            case "training_schedule":
                selectedTab = 1
                pendingRoute = .trainingSchedule
            case "nutrition":
                selectedTab = 0
                pendingRoute = .nutrition
            case "body_checkin":
                selectedTab = 0
                pendingRoute = .bodyCheckIn
            case "profile_edit":
                selectedTab = 4
                pendingRoute = .profileEdit
            case "workout_history":
                selectedTab = 1
                pendingRoute = .workoutHistory
            case "agent_memory":
                selectedTab = 4
                pendingRoute = .agentMemory
            case "period_schedule":
                selectedTab = 1
                pendingRoute = .periodSchedule
            default:
                return "暂不支持打开 \(screen)"
            }
            return "正在打开\(action.title)"

        case "start_training":
            let draftFallback = draftPlanDay.flatMap { isPlanDayCompleted($0) ? nil : $0 }
            let todayFallback = todayDay.flatMap { isPlanDayCompleted($0) ? nil : $0 }
            let upcomingFallback = plan?.days
                .filter { $0.skippedAt == nil && !isPlanDayCompleted($0) }
                .sorted { lhs, rhs in
                    let lhsDate = plan?.scheduledDate(for: lhs) ?? .distantFuture
                    let rhsDate = plan?.scheduledDate(for: rhs) ?? .distantFuture
                    return lhsDate < rhsDate
                }
                .first
            let day = resolveActionPlanDay(action.payload)
                ?? draftFallback
                ?? todayFallback
                ?? upcomingFallback
            guard let day else { return "没有找到可以开始的训练" }
            selectedTab = 0
            workoutLaunchDayID = day.id
            return "正在打开「\(day.title)」训练"

        case "reschedule_training":
            guard let day = resolveActionPlanDay(action.payload) else {
                return "没有找到要改期的训练"
            }
            let before = scheduleUndoState(for: day)
            if let targetText = action.payload?.targetDate,
               targetText != "next_free",
               let target = FitnessDate.date(from: targetText) {
                let moved = reschedulePlanDay(day, to: target)
                if moved, let before { undo = before }
                return moved
                    ? "已将「\(day.title)」改到 \(FitnessDate.short(target))"
                    : "改期失败，目标日期可能已有训练"
            }
            let moved = deferPlanDay(day)
            if moved, let before { undo = before }
            return moved
                ? "已将「\(day.title)」顺延到最近空档"
                : "顺延失败，没有可用空档"

        case "skip_training":
            guard let day = resolveActionPlanDay(action.payload) else {
                return "没有找到要跳过的训练"
            }
            let before = scheduleUndoState(for: day)
            let skipped = skipPlanDay(day)
            if skipped, let before { undo = before }
            return skipped
                ? "已跳过「\(day.title)」"
                : "跳过失败"

        case "update_goal":
            guard let payload = action.payload else { return "目标参数为空" }
            let previousProfile = profile
            var updated = profile
            switch payload.goalType {
            case "lose_fat": updated.goalType = .loseFat
            case "build_muscle": updated.goalType = .buildMuscle
            case "recomp": updated.goalType = .recomp
            case "endurance": updated.goalType = .endurance
            default: break
            }
            if let weight = payload.targetWeightKG {
                updated.targetWeightKG = weight
            }
            if let days = payload.weeklyDays {
                updated.weeklyDays = min(7, max(1, days))
            }
            if let minutes = payload.sessionMinutes {
                updated.sessionMinutes = min(180, max(15, minutes))
            }
            if let targetText = payload.targetDate,
               let date = FitnessDate.date(from: targetText) {
                updated.targetDate = date
            }
            updateProfile(updated)
            undo = .profile(previousProfile)
            return "已更新训练目标"

        case "log_body_metric":
            guard let payload = action.payload else {
                return "没有提供身体数据"
            }
            guard payload.weightKG != nil || payload.bodyFatPCT != nil || payload.waistCM != nil else {
                return "至少填写一项身体数据"
            }
            let previousProfile = profile
            let todayKey = FitnessDate.key(Date())
            let previousMetric = bodyMetrics.first { $0.dateKey == todayKey }
            let metric = saveBodyCheckIn(
                weightKG: payload.weightKG,
                bodyFatPCT: payload.bodyFatPCT,
                waistCM: payload.waistCM
            )
            undo = .bodyMetric(
                metricID: metric.id,
                previousMetric: previousMetric,
                previousProfile: previousProfile
            )
            if let weight = payload.weightKG {
                return "已记录体重 \(weight.formatted(.number.precision(.fractionLength(1)))) kg"
            }
            if let bodyFat = payload.bodyFatPCT {
                return "已记录体脂约 \(bodyFat.formatted(.number.precision(.fractionLength(0))))%"
            }
            return "已记录身体数据"

        case "create_diet_plan":
            let strategy = action.payload?.strategy ?? "balanced"
            let weekStart = action.payload?.weekStart
            Task { @MainActor in
                do {
                    let week = try await APIClient.shared.fetchDietWeek(
                        strategy: strategy,
                        weekStart: weekStart
                    )
                    self.dietWeekPlan = week
                } catch {
                    self.toast = "饮食计划生成失败，请稍后重试"
                }
            }
            return "正在生成本周饮食计划…"

        case "recognize_equipment":
            coachEquipmentScanRequested = true
            return "正在打开器械识别…"

        case "analyze_body":
            coachBodyAnalysisRequested = true
            return "正在打开体型分析…"

        case "modify_workout":
            guard let payload = action.payload,
                  let changes = payload.changes,
                  !changes.isEmpty else {
                return "没有收到具体的改课内容"
            }
            guard var current = plan else {
                return "还没有训练计划，无法改课"
            }
            guard let target = resolveActionPlanDay(payload)
                ?? defaultWorkoutDayForAgent(in: current) else {
                return "没有找到可以修改的训练日"
            }
            let previousPlan = current
            let outcome = applyWorkoutChanges(
                changes,
                to: &current,
                dayID: target.id,
                scope: payload.scope ?? "day"
            )
            guard outcome.applied > 0 else {
                return outcome.message
            }
            current.version += 1
            current.updatedAt = Date()
            plan = current
            undo = .plan(previousPlan)
            persist()
            rescheduleNotifications()
            syncPendingUserData()
            return outcome.message

        default:
            return "暂不支持操作：\(action.type)"
        }
    }

    private struct WorkoutChangeOutcome {
        let applied: Int
        let message: String
    }

    private func defaultWorkoutDayForAgent(in plan: TrainingPlan) -> PlanDay? {
        if let today = todayDay, !isPlanDayCompleted(today) {
            return today
        }
        return plan.days
            .filter { $0.skippedAt == nil && !isPlanDayCompleted($0) }
            .sorted {
                (plan.scheduledDate(for: $0) ?? .distantFuture)
                    < (plan.scheduledDate(for: $1) ?? .distantFuture)
            }
            .first
    }

    private func applyWorkoutChanges(
        _ changes: [AgentWorkoutChange],
        to plan: inout TrainingPlan,
        dayID: UUID,
        scope: String
    ) -> WorkoutChangeOutcome {
        let targetIndexes: [Int]
        if scope == "plan" {
            targetIndexes = Array(plan.days.indices)
        } else if let index = plan.days.firstIndex(where: { $0.id == dayID }) {
            targetIndexes = [index]
        } else {
            return WorkoutChangeOutcome(applied: 0, message: "没有找到要修改的训练日")
        }

        var applied = 0
        var notes: [String] = []

        func name(of slug: String) -> String {
            ExerciseLibrary.exercise(slug: slug)?.nameZH ?? slug
        }

        // Structural changes first so a following weight/sets op can address
        // the replacement exercise, regardless of the model's array order.
        let orderedChanges = changes.filter { $0.op == "swap" || $0.op == "add" }
            + changes.filter { $0.op != "swap" && $0.op != "add" }
        for change in orderedChanges {
            switch change.op {
            case "swap":
                guard let from = change.fromSlug,
                      let to = change.toSlug,
                      let replacement = ExerciseLibrary.exercise(slug: to) else {
                    notes.append("动作库里没有 \(change.toSlug ?? "目标动作")")
                    continue
                }
                var swapped = 0
                for index in targetIndexes {
                    var exercises = plan.days[index].exercises
                    guard let exerciseIndex = exercises.firstIndex(where: { $0.slug == from }) else {
                        continue
                    }
                    guard !exercises.contains(where: { $0.slug == to }) else {
                        continue
                    }
                    let original = exercises[exerciseIndex]
                    exercises[exerciseIndex] = PlanExercise(
                        slug: replacement.slug,
                        sets: original.sets,
                        reps: original.reps,
                        weightKG: nil,
                        restSec: original.restSec,
                        rpe: original.rpe
                    )
                    plan.days[index].exercises = exercises
                    swapped += 1
                }
                if swapped > 0 {
                    applied += swapped
                    notes.append("\(name(of: from)) → \(replacement.nameZH)")
                }

            case "sets":
                guard let slug = change.slug, let sets = change.sets else { continue }
                let value = min(max(sets, 1), 10)
                let updated = updateWorkoutExercises(
                    in: &plan,
                    indexes: targetIndexes,
                    slug: slug
                ) { exercise in
                    exercise.sets = value
                    return true
                }
                if updated > 0 {
                    applied += updated
                    notes.append("\(name(of: slug)) 改为 \(value) 组")
                }

            case "reps":
                guard let slug = change.slug,
                      let reps = change.reps,
                      !reps.isEmpty else { continue }
                let value = String(reps.prefix(20))
                let updated = updateWorkoutExercises(
                    in: &plan,
                    indexes: targetIndexes,
                    slug: slug
                ) { exercise in
                    exercise.reps = value
                    return true
                }
                if updated > 0 {
                    applied += updated
                    notes.append("\(name(of: slug)) 改为 \(value)")
                }

            case "weight":
                guard let slug = change.slug, let weight = change.weightKG else { continue }
                let updated = updateWorkoutExercises(
                    in: &plan,
                    indexes: targetIndexes,
                    slug: slug
                ) { exercise in
                    exercise.weightKG = weight > 0 ? weight : nil
                    return true
                }
                if updated > 0 {
                    applied += updated
                    notes.append("\(name(of: slug)) 重量 \(weight.formatted())kg")
                }

            case "rest":
                guard let slug = change.slug, let rest = change.restSec else { continue }
                let value = min(max(rest, 0), 300)
                let updated = updateWorkoutExercises(
                    in: &plan,
                    indexes: targetIndexes,
                    slug: slug
                ) { exercise in
                    exercise.restSec = value
                    return true
                }
                if updated > 0 {
                    applied += updated
                    notes.append("\(name(of: slug)) 休息 \(value)s")
                }

            case "remove":
                guard let slug = change.slug else { continue }
                var removed = 0
                for index in targetIndexes {
                    var exercises = plan.days[index].exercises
                    guard exercises.count > 1,
                          let exerciseIndex = exercises.firstIndex(where: { $0.slug == slug }) else {
                        continue
                    }
                    exercises.remove(at: exerciseIndex)
                    plan.days[index].exercises = exercises
                    removed += 1
                }
                if removed > 0 {
                    applied += removed
                    notes.append("移除 \(name(of: slug))")
                }

            case "add":
                guard let slug = change.slug,
                      let replacement = ExerciseLibrary.exercise(slug: slug),
                      let index = plan.days.firstIndex(where: { $0.id == dayID }) else {
                    continue
                }
                guard !plan.days[index].exercises.contains(where: { $0.slug == slug }) else {
                    continue
                }
                plan.days[index].exercises.append(
                    PlanExercise(
                        slug: replacement.slug,
                        sets: min(max(change.sets ?? 3, 1), 10),
                        reps: change.reps ?? "10-12",
                        weightKG: change.weightKG,
                        restSec: min(max(change.restSec ?? 60, 0), 300),
                        rpe: 7.5
                    )
                )
                applied += 1
                notes.append("加入 \(replacement.nameZH)")

            default:
                continue
            }
        }

        let message = notes.isEmpty
            ? "没有找到可以修改的动作"
            : "已改课：" + notes.joined(separator: "；") + "。"
        return WorkoutChangeOutcome(applied: applied, message: message)
    }

    private func updateWorkoutExercises(
        in plan: inout TrainingPlan,
        indexes: [Int],
        slug: String,
        transform: (inout PlanExercise) -> Bool
    ) -> Int {
        var updated = 0
        for index in indexes {
            var exercises = plan.days[index].exercises
            var changed = false
            for exerciseIndex in exercises.indices where exercises[exerciseIndex].slug == slug {
                if transform(&exercises[exerciseIndex]) {
                    changed = true
                    updated += 1
                }
            }
            if changed {
                plan.days[index].exercises = exercises
            }
        }
        return updated
    }

    private func scheduleUndoState(for day: PlanDay) -> AgentUndoState? {
        guard let plan,
              let current = plan.days.first(where: { $0.id == day.id }) else {
            return nil
        }
        return .schedule(
            planID: plan.id,
            dayID: current.id,
            previousDate: current.date,
            previousWeekday: current.weekday,
            previousWeekIndex: current.weekIndex,
            previousSkippedAt: current.skippedAt
        )
    }

    func undoLastAgentAction() {
        guard let pending = pendingUndo else { return }
        pendingUndo = nil
        guard Date() < pending.expiresAt else {
            toast = "撤销窗口已结束"
            return
        }
        let now = Date()
        let succeeded = undoSingleAction(pending.state, at: now)
        if case let .batch(states) = pending.state {
            toast = succeeded
                ? "已撤销本次 \(states.count) 项修改"
                : "部分修改撤销失败，请检查计划"
        }
        Task {
            try? await APIClient.shared.reportAgentAction(
                id: pending.id,
                runID: pending.runID,
                type: pending.actionType,
                status: "undone",
                message: "用户撤销"
            )
        }
    }

    @discardableResult
    private func undoSingleAction(_ state: AgentUndoState, at now: Date) -> Bool {
        switch state {
        case let .batch(states):
            var allSucceeded = true
            for item in states {
                if !undoSingleAction(item, at: now) {
                    allSucceeded = false
                }
            }
            return allSucceeded

        case let .schedule(
            planID,
            dayID,
            previousDate,
            previousWeekday,
            previousWeekIndex,
            previousSkippedAt
        ):
            guard var current = plan,
                  current.id == planID,
                  let index = current.days.firstIndex(where: { $0.id == dayID }) else {
                toast = "当前计划已变化，无法撤销"
                return false
            }
            current.days[index].date = previousDate
            current.days[index].weekday = previousWeekday
            current.days[index].weekIndex = previousWeekIndex
            current.days[index].skippedAt = previousSkippedAt
            current.days[index].scheduleUpdatedAt = now
            current.version += 1
            current.updatedAt = now
            plan = current
            persist()
            rescheduleNotifications()
            syncPendingUserData()
            toast = "已撤销排期修改"
            return true

        case let .bodyMetric(metricID, previousMetric, previousProfile):
            removeBodyMetric(id: metricID)
            profile = previousProfile
            if let previousMetric {
                appendBodyMetric(previousMetric)
            }
            persist()
            syncPendingUserData()
            Task {
                try? await APIClient.shared.syncProfile(previousProfile)
                try? await APIClient.shared.syncGoal(previousProfile)
            }
            toast = "已撤销身体数据"
            return true

        case let .plan(previousPlan):
            guard let current = plan, current.id == previousPlan.id else {
                toast = "当前计划已变化，无法撤销改课"
                return false
            }
            plan = previousPlan
            persist()
            rescheduleNotifications()
            syncPendingUserData()
            toast = "已撤销改课"
            return true

        case let .profile(previousProfile):
            updateProfile(previousProfile)
            toast = "已撤销目标修改"
            return true
        }
    }

    private func resolveActionPlanDay(_ payload: AgentActionPayload?) -> PlanDay? {
        guard let plan else { return nil }
        if let id = payload?.dayID, let uuid = UUID(uuidString: id) {
            return plan.days.first { $0.id == uuid }
        }
        if let value = payload?.date, let date = FitnessDate.date(from: value) {
            if let matched = plan.day(on: date) {
                return matched
            }
            let key = FitnessDate.key(date)
            return plan.days.first {
                plan.scheduledDate(for: $0).map { FitnessDate.key($0) == key } == true
            }
        }
        return nil
    }

    func applyAgentProposal() {
        guard let proposal = agentProposal, !isAgentWorking else { return }
        isAgentWorking = true
        Task { @MainActor in
            defer {
                self.isAgentWorking = false
                self.persist()
            }
            do {
                let updated = try await APIClient.shared.applyAgentProposal(id: proposal.id)
                self.archiveCurrentPlan()
                self.plan = updated
                if let proposed = proposal.proposed {
                    if let days = proposed.weeklyDays {
                        self.profile.weeklyDays = max(1, min(7, days))
                    }
                    if let minutes = proposed.sessionMinutes {
                        self.profile.sessionMinutes = max(15, min(180, minutes))
                    }
                    if let focus = proposed.focus {
                        let values = focus.compactMap { BodyFocusArea(rawValue: $0)?.rawValue }
                        UserDefaults.standard.set(
                            values.prefix(2).joined(separator: ","),
                            forKey: "fitai_focus_areas"
                        )
                    }
                }
                self.agentProposal = nil
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "计划已应用到你的正式计划。后续训练日、时长和动作会按新版本执行。"
                    )
                )
                self.toast = "已应用 Agent 计划"
                self.rescheduleNotifications()
                self.syncPendingUserData()
            } catch let error as APIError where error.isProRequired {
                await self.refreshAccess()
                self.requestPro(.trainingPlan)
            } catch {
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "计划草案应用失败：\(error.localizedDescription)"
                    )
                )
            }
        }
    }

    func dismissAgentProposal() {
        agentProposal = nil
        persist()
    }

}
