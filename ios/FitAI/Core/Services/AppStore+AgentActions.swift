import Foundation

extension AppStore {
    // MARK: - App Action 执行层

    func agentAppContext(pendingActions: [AgentAction] = []) -> [String: Any] {
        var context: [String: Any] = [
            "today": FitnessDate.key(Date()),
            "selected_tab": selectedTab,
        ]
        if let action = pendingActions.last,
           let payload = action.payload,
           action.type == "log_food" {
            var snapshot: [String: Any] = [
                "id": action.id,
                "type": action.type,
            ]
            var fields: [String: Any] = [:]
            if let date = payload.date { fields["date"] = date }
            if let meal = payload.meal { fields["meal"] = meal }
            if let items = payload.items {
                fields["items"] = items.map { item -> [String: Any] in
                    [
                        "name": item.name,
                        "portion": item.portion ?? "",
                        "grams": item.grams,
                        "kcal": item.kcal,
                        "protein_g": item.proteinG,
                        "carbs_g": item.carbsG,
                        "fat_g": item.fatG,
                        "confidence": item.confidence ?? 0,
                    ]
                }
            }
            snapshot["payload"] = fields
            context["pending_action"] = snapshot
        }
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

    func updateAgentFoodAction(
        actionID: String,
        items: [AgentFoodItem],
        date: String?,
        meal: MealType?
    ) {
        guard let index = agentActions.firstIndex(where: { $0.id == actionID }) else {
            return
        }
        agentActions[index].payload?.items = items
        if let date {
            agentActions[index].payload?.date = date
        }
        if let meal {
            agentActions[index].payload?.meal = meal.rawValue
        }
        let kcal = items.reduce(0) { $0 + $1.kcal }
        agentActions[index].summary = "约 \(Int(kcal)) kcal"
        persist()
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
            var failedCount = 0
            for action in actions {
                var undoState: AgentUndoState?
                let message = await self.executeAgentAction(action, undo: &undoState)
                results.append(message)
                let status = self.agentActionStatus(for: message)
                if status == "failed" {
                    failedCount += 1
                } else if let undoState {
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
                    text: "处理结果：\n" + results.joined(separator: "\n")
                )
            )
            if actions.contains(where: {
                ["log_food", "log_planned_meal", "skip_planned_meal", "restore_planned_meal"].contains($0.type)
            }) {
                self.pendingDraft = nil
            }
            if failedCount == actions.count {
                self.toast = "操作失败，请查看处理结果"
            } else if failedCount > 0 {
                self.toast = "部分操作未完成，请查看处理结果"
            } else {
                self.toast = "Agent 操作已执行"
            }
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
    ) async -> String {
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
                } catch let error as APIError where error.isProRequired {
                    await self.refreshAccess()
                    self.requestPro(.mealPlan)
                    self.toast = "本周饮食计划需要 Pro，已为你打开订阅选项"
                } catch {
                    self.toast = "饮食计划生成失败，请稍后重试"
                }
            }
            return "正在生成本周饮食计划…"

        case "swap_diet_meal":
            guard let payload = action.payload,
                  let mealRaw = payload.meal,
                  let meal = MealType(rawValue: mealRaw) else {
                return "没有指定要替换哪一餐"
            }
            let dateString = payload.date ?? FitnessDate.key(Date())
            do {
                let plan = try await APIClient.shared.swapDietMeal(
                    dateString: dateString,
                    meal: meal
                )
                let mealName = plan.meals.first { $0.meal == mealRaw }?.name ?? "新餐"
                if let week = try? await NutritionService().fetchSavedWeek(weekStart: nil) {
                    dietWeekPlan = week
                }
                let dayText = FitnessDate.date(from: dateString).map {
                    FitnessDate.short($0)
                } ?? dateString
                return "已把 \(dayText) \(meal.label)换成「\(mealName)」"
            } catch let error as APIError where error.statusCode == 404 {
                return "没有找到这一天保存的饮食计划"
            } catch {
                return "换餐失败：\(error.localizedDescription)"
            }

        case "log_food", "log_planned_meal", "update_food_log", "delete_food_log":
            guard let payload = action.payload else {
                return "没有收到饮食记录参数"
            }
            do {
                let response = try await APIClient.shared.runAgentAction(
                    id: action.id,
                    type: action.type,
                    payload: payload
                )
                let result = response.result
                if let logs = result?.createdLogs {
                    mergeRemoteFoodLogs(logs)
                }
                if let updated = result?.updatedLog {
                    mergeRemoteFoodLogs([updated])
                }
                if let deleted = result?.deletedLog,
                   let id = UUID(uuidString: deleted.clientID) {
                    foodLogs.removeAll { $0.id == id }
                    persist()
                }
                syncPendingUserData()
                refreshWeeklyReview(force: true)
                await refreshDailyNutritionTargets()
                if action.type == "log_food" || action.type == "log_planned_meal" {
                    undo = .foodLogAction(actionID: action.id)
                } else if action.type == "update_food_log" || action.type == "delete_food_log" {
                    undo = .foodLogEditAction(actionID: action.id)
                }
                if action.type == "delete_food_log" {
                    return "已删除饮食记录"
                }
                return action.summary.isEmpty
                    ? "已记录饮食"
                    : "已记录：\(action.summary)"
            } catch let error as APIError where error.statusCode == 404 {
                return "没有找到可修改的饮食记录"
            } catch let error as APIError where error.statusCode == 422 {
                return "饮食记录失败：参数不合法"
            } catch {
                return "记录饮食失败：\(error.localizedDescription)"
            }

        case "log_workout":
            guard let payload = action.payload else {
                return "没有收到训练记录参数"
            }
            do {
                _ = try await APIClient.shared.runAgentAction(
                    id: action.id,
                    type: action.type,
                    payload: payload
                )
                syncRemoteWorkouts()
                undo = .workoutAction(actionID: action.id)
                return action.summary.isEmpty
                    ? "已记录训练"
                    : "已记录：\(action.summary)"
            } catch let error as APIError where error.statusCode == 404 {
                return "没有找到要修改的训练记录"
            } catch let error as APIError where error.statusCode == 422 {
                return "训练记录失败：参数不合法"
            } catch {
                return "记录训练失败：\(error.localizedDescription)"
            }

        case "update_workout_log", "delete_workout_log":
            guard let payload = action.payload else {
                return "没有收到训练记录参数"
            }
            do {
                _ = try await APIClient.shared.runAgentAction(
                    id: action.id,
                    type: action.type,
                    payload: payload
                )
                syncRemoteWorkouts()
                undo = .workoutEditAction(actionID: action.id)
                return action.type == "delete_workout_log"
                    ? "已删除训练记录"
                    : "已更新训练记录"
            } catch let error as APIError where error.statusCode == 404 {
                return "没有找到这条训练记录"
            } catch let error as APIError where error.statusCode == 422 {
                return "训练记录失败：参数不合法"
            } catch {
                return "更新训练失败：\(error.localizedDescription)"
            }

        case "skip_planned_meal", "restore_planned_meal":
            guard let payload = action.payload else {
                return "没有收到计划餐参数"
            }
            do {
                _ = try await APIClient.shared.runAgentAction(
                    id: action.id,
                    type: action.type,
                    payload: payload
                )
                undo = .mealPlanStateAction(actionID: action.id)
                return action.type == "skip_planned_meal"
                    ? "已跳过这餐"
                    : "已恢复这餐"
            } catch let error as APIError where error.statusCode == 404 {
                return "没有找到这一餐的计划"
            } catch let error as APIError where error.statusCode == 422 {
                return "计划餐操作失败：已记录或参数不合法"
            } catch {
                return "计划餐操作失败：\(error.localizedDescription)"
            }

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
            guard (payload.scope ?? "day") == "day" else {
                return "暂不支持一次改整个计划，请按训练日改"
            }
            guard let current = plan else {
                return "还没有训练计划，无法改课"
            }
            guard let target = resolveActionPlanDay(payload)
                ?? defaultWorkoutDayForAgent(in: current) else {
                return "没有找到可以修改的训练日"
            }
            do {
                let updated = try await APIClient.shared.executeWorkoutAction(
                    actionID: action.id,
                    planID: current.id.uuidString,
                    dayID: target.id.uuidString,
                    expectedPlanVersion: current.version,
                    changes: changes
                )
                guard let merged = mergeServerWorkoutPlan(
                    updated,
                    into: current,
                    dayID: target.id
                ) else {
                    return "改课失败：服务端返回的计划不一致"
                }
                plan = merged
                undo = .serverWorkoutAction(
                    actionID: action.id,
                    planID: current.id,
                    dayID: target.id
                )
                persist()
                rescheduleNotifications()
                syncPendingUserData()
                return action.summary.isEmpty
                    ? "已改课"
                    : "已改课：\(action.summary)"
            } catch let error as APIError where error.statusCode == 409 {
                return "计划已经更新，请重新生成改课方案"
            } catch {
                return "改课失败：\(error.localizedDescription)"
            }

        default:
            return "暂不支持操作：\(action.type)"
        }
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

    func mergeServerWorkoutPlan(
        _ updated: TrainingPlan,
        into current: TrainingPlan,
        dayID: UUID
    ) -> TrainingPlan? {
        guard updated.id == current.id,
              let serverDay = updated.days.first(where: { $0.id == dayID }),
              let index = current.days.firstIndex(where: { $0.id == dayID }) else {
            return nil
        }
        var result = current
        result.days[index].exercises = serverDay.exercises
        result.version = updated.version
        result.updatedAt = Date()
        return result
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
        guard workoutDraft == nil else {
            toast = "你正在训练；请先保存或结束当前训练，再应用新计划"
            return
        }
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
                self.planNeedsServerSync = false
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
