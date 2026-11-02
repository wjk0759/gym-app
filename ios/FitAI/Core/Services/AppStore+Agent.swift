import Foundation

extension AppStore {
    func sendChat(_ text: String, skill: CoachSkill = .trainer) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        cancelActiveChatRequest()
        removeTrailingChatTimeoutNotices()
        lastAgentRetryText = nil
        chat.append(ChatMessage(role: .user, text: trimmed))

        if canUseRemoteAI {
            let requestID = UUID()
            legacyChatRequestID = requestID
            isReplying = true
            persist()

            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    if self.legacyChatRequestID == requestID {
                        self.legacyChatRequestID = nil
                        self.legacyChatTask = nil
                        self.legacyChatWatchdog?.cancel()
                        self.legacyChatWatchdog = nil
                        self.isReplying = false
                        self.persist()
                    }
                }
                do {
                    let response = try await APIClient.shared.sendChat(
                        message: trimmed,
                        skill: skill,
                        context: self.coachContextForReply
                    )
                    try Task.checkCancellation()
                    self.chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: response.reply,
                            isSafety: response.safetyFlag != nil
                        )
                    )
                } catch is CancellationError {
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    let local = CoachService.reply(
                        to: trimmed,
                        profile: self.profile,
                        plan: self.plan,
                        skill: skill,
                        period: self.todayPeriod
                    )
                    self.toast = "远程 AI 暂时不可用，已使用本地建议"
                    self.chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: "远程 AI 暂时不可用，先用本地规则回答：\n\n" + local.text,
                            isSafety: local.isSafety
                        )
                    )
                }
            }
            legacyChatTask = task
            legacyChatWatchdog = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: Self.chatRequestTimeoutNanoseconds)
                guard !Task.isCancelled,
                      let self,
                      self.legacyChatRequestID == requestID,
                      self.isReplying else { return }
                self.legacyChatRequestID = nil
                task.cancel()
                self.legacyChatTask = nil
                self.legacyChatWatchdog = nil
                self.isReplying = false
                self.chat.append(
                    ChatMessage(role: .assistant, text: Self.legacyTimeoutNotice)
                )
                self.persist()
            }
            return
        }

        chat.append(
            CoachService.reply(
                to: trimmed,
                profile: profile,
                plan: plan,
                skill: skill,
                period: todayPeriod
            )
        )
        persist()
    }

    func clearChat() {
        cancelActiveChatRequest()
        chat.removeAll()
        planAdjustmentStage = 0
        planAdjustmentProposal = nil
        planAdjustmentRequested = false
        agentSessionID = nil
        agentRunID = nil
        agentProposal = nil
        agentActions = []
        coachVisualMemory = nil
        isExecutingAgentActions = false
        workoutLaunchDayID = nil
        lastAgentRetryText = nil
        lastAgentRetrySkill = .trainer
        pendingUndo = nil
        isReplying = false
        persist()
    }

    // MARK: - Coach Agent

    /// 后台生成的周复盘会落到 AgentRun，前台只读取结果；同一周默认复用缓存。
    func refreshWeeklyReview(force: Bool = false, notifyWhenReady: Bool = false) {
        guard AuthTokenStore.shared.accessToken != nil, hasProAccess else { return }
        if isReviewingWeekly {
            if force {
                reviewRefreshQueued = true
                reviewNotifyQueued = reviewNotifyQueued || notifyWhenReady
            }
            return
        }
        if !force,
           let weeklyReview,
           Self.isSameWeek(weeklyReview.generatedAt, Date()) {
            return
        }
        let accountID = currentUserID
        isReviewingWeekly = true
        Task { @MainActor in
            defer {
                self.isReviewingWeekly = false
                if self.reviewRefreshQueued {
                    self.reviewRefreshQueued = false
                    let queuedNotify = self.reviewNotifyQueued
                    self.reviewNotifyQueued = false
                    self.refreshWeeklyReview(force: true, notifyWhenReady: queuedNotify)
                }
            }
            do {
                let review = try await APIClient.shared.agentWeeklyReview()
                guard self.currentUserID == accountID else { return }
                self.weeklyReview = review
                self.persist()
                if notifyWhenReady, self.notificationsEnabled {
                    NotificationScheduler.shared.notifyReviewReady()
                }
            } catch {
                // 离线时保留上周复盘；下一次前台刷新或训练完成后重试。
            }
        }
    }

    private static func isSameWeek(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: lhs)
                == calendar.component(.weekOfYear, from: rhs)
            && calendar.component(.yearForWeekOfYear, from: lhs)
                == calendar.component(.yearForWeekOfYear, from: rhs)
    }

    func sendAgentChat(
        _ text: String,
        skill: CoachSkill = .trainer,
        appendUserMessage: Bool = true,
        requestID: UUID? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cancelActiveChatRequest()
        removeTrailingChatTimeoutNotices()
        if appendUserMessage {
            chat.append(ChatMessage(role: .user, text: trimmed))
        }

        let activeRequestID = requestID ?? UUID()
        agentChatRequestID = activeRequestID
        lastAgentRequestID = activeRequestID
        isReplying = true
        agentProposal = nil
        agentActions = []
        agentRunID = nil
        lastAgentRetryText = nil
        pendingUndo = nil
        persist()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                // 旧请求或被取消的请求不能覆盖新请求的 UI 状态。
                if self.agentChatRequestID == activeRequestID {
                    self.agentChatRequestID = nil
                    self.agentChatTask = nil
                    self.agentChatWatchdog?.cancel()
                    self.agentChatWatchdog = nil
                    self.isReplying = false
                    self.persist()
                }
            }
            do {
                let context = self.agentAppContext()
                let response: AgentChatResponse
                do {
                    response = try await APIClient.shared.agentChat(
                        message: trimmed,
                        sessionID: self.agentSessionID,
                        skill: skill,
                        appContext: context,
                        requestID: activeRequestID
                    )
                } catch let error as APIError where error.statusCode == 404 {
                    // 后端数据库可能已经清理/切换账号，旧 session 会让请求 404；
                    // 清空 session 后重试一次，避免误报“远程 AI 不可用”。
                    self.agentSessionID = nil
                    response = try await APIClient.shared.agentChat(
                        message: trimmed,
                        sessionID: nil,
                        skill: skill,
                        appContext: context,
                        requestID: activeRequestID
                    )
                }
                try Task.checkCancellation()
                self.agentSessionID = response.sessionID
                self.agentRunID = response.runID
                if response.status == "failed" {
                    self.lastAgentRetryText = trimmed
                    self.lastAgentRetrySkill = skill
                    self.chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: "这次请求没有完成，可能是模型服务短暂异常。已保留这次输入，点下方重试。"
                        )
                    )
                    return
                }
                self.agentProposal = response.proposal
                self.agentActions = response.actions ?? []
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: response.reply,
                        isSafety: response.safetyFlag != nil
                    )
                )
                self.lastAgentRetryText = nil
                self.lastAgentRequestID = nil
                Task { await self.refreshAccess() }
            } catch is CancellationError {
                return
            } catch let error as APIError where error.isCoachQuotaExhausted {
                self.requestPro(.coachAI)
                return
            } catch let error as APIError where error.isRateLimited || error.statusCode == 429 {
                self.toast = "请求太频繁，请稍后再试"
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.lastAgentRetryText = trimmed
                self.lastAgentRetrySkill = skill
                let local = CoachService.reply(
                    to: trimmed,
                    profile: self.profile,
                    plan: self.plan,
                    skill: skill,
                    period: self.todayPeriod
                )
                self.toast = "远程 AI 暂时不可用，已使用本地建议"
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "远程 AI 暂时不可用，先用本地规则回答：\n\n" + local.text,
                        isSafety: local.isSafety
                    )
                )
            }
        }
        agentChatTask = task

        // 网络请求和模型服务偶尔会长时间不返回；给 UI 一个明确的超时出口。
        agentChatWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.chatRequestTimeoutNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  self.agentChatRequestID == activeRequestID,
                  self.isReplying else { return }
            self.agentChatRequestID = nil
            task.cancel()
            self.agentChatTask = nil
            self.agentChatWatchdog = nil
            self.isReplying = false
            self.lastAgentRetryText = trimmed
            self.lastAgentRetrySkill = skill
            self.chat.append(ChatMessage(role: .assistant, text: Self.agentTimeoutNotice))
            self.persist()
        }
    }

    /// 用户主动停止当前回复，不等待网络请求自然结束。
    func cancelAgentChat() {
        guard isReplying else { return }
        cancelActiveChatRequest()
        lastAgentRetryText = nil
        chat.append(ChatMessage(role: .assistant, text: "已停止本次回复。"))
        persist()
    }

    /// 重试/新消息前清掉上一次请求留下的超时气泡，避免同一个问题堆出多条错误提示。
    func removeTrailingChatTimeoutNotices() {
        while let last = chat.last,
              last.role == .assistant,
              Self.chatTimeoutNotices.contains(last.text) {
            chat.removeLast()
        }
    }

    func cancelActiveChatRequest() {
        agentChatRequestID = nil
        lastAgentRequestID = nil
        agentChatTask?.cancel()
        agentChatTask = nil
        agentChatWatchdog?.cancel()
        agentChatWatchdog = nil
        coachPhotoRequestID = nil
        coachPhotoTask?.cancel()
        coachPhotoTask = nil
        coachPhotoWatchdog?.cancel()
        coachPhotoWatchdog = nil
        legacyChatRequestID = nil
        legacyChatTask?.cancel()
        legacyChatTask = nil
        legacyChatWatchdog?.cancel()
        legacyChatWatchdog = nil
        isReplying = false
    }

    func retryAgentChat() {
        guard let text = lastAgentRetryText, !isReplying else { return }
        let skill = lastAgentRetrySkill
        let requestID = lastAgentRequestID
        lastAgentRetryText = nil
        sendAgentChat(
            text,
            skill: skill,
            appendUserMessage: false,
            requestID: requestID
        )
    }

    // MARK: - App Action 执行层

    private func agentAppContext() -> [String: Any] {
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

        default:
            return "暂不支持操作：\(action.type)"
        }
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

    // MARK: - 档案与提醒
}
