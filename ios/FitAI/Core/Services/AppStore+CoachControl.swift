import Foundation
import UIKit

/// New server-owned coach control plane.
///
/// The legacy `sendAgentChat` path stays available for capabilities not yet
/// migrated. Only food logging and training rescheduling route here for now.
extension AppStore {
    var coachInboxUnreadCount: Int {
        coachInbox.filter { $0.status == "unread" }.count
    }

    func markAllCoachInboxRead() {
        guard coachInboxUnreadCount > 0 else { return }
        coachInbox = coachInbox.map { item in
            guard item.status == "unread" else { return item }
            return CoachInboxItem(
                id: item.id,
                kind: item.kind,
                title: item.title,
                body: item.body,
                capabilityID: item.capabilityID,
                payload: item.payload,
                status: "read",
                createdAt: item.createdAt
            )
        }
        persist()
        Task {
            try? await APIClient.shared.markAllCoachInboxRead()
        }
    }

    func openCoach(prompt: String) {
        coachEntryPrompt = prompt
        selectedTab = 2
    }

    func sendCoachControlTurn(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCoachControlWorking, !isReplying else { return }
        cancelActiveChatRequest()
        chat.append(ChatMessage(role: .user, text: trimmed))
        isCoachControlWorking = true
        isReplying = true
        coachReceipt = nil
        persist()

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isCoachControlWorking = false
                self.isReplying = false
                self.persist()
            }
            do {
                let response = try await APIClient.shared.coachTurn(
                    message: trimmed,
                    sessionID: self.coachSessionID,
                    appContext: self.agentAppContext()
                )
                if self.coachSessionID != response.session.id {
                    self.coachHistoryHasMore = false
                    self.coachHistoryCursor = nil
                }
                self.coachSessionID = response.session.id
                self.coachSession = response.session
                self.coachPending = response.pending
                if let index = self.chat.lastIndex(where: {
                    $0.role == .user
                        && $0.serverMessageID == nil
                        && $0.text == trimmed
                }) {
                    self.chat[index].serverMessageID = "coach-\(response.turnID)-user"
                }
                var assistant = ChatMessage(
                    role: .assistant,
                    text: response.reply
                )
                assistant.isSafety = response.intent == "safety"
                assistant.serverMessageID = "coach-\(response.turnID)-assistant"
                self.chat.append(assistant)
                Telemetry.shared.track(
                    "coach_turn_completed",
                    properties: [
                        "intent": response.intent ?? "unknown",
                        "status": response.status,
                    ]
                )
                if response.intent == "safety" {
                    Telemetry.shared.track("coach_safety_block")
                }
                self.coachQuotaExhausted = false
                Task { await self.refreshAccess() }
                self.persist()
            } catch is CancellationError {
                return
            } catch let error as APIError where error.isCoachQuotaExhausted {
                Telemetry.shared.track(
                    "coach_turn_failed",
                    properties: ["stage": "quota"]
                )
                self.coachQuotaExhausted = true
                self.toast = "今日免费额度已用完"
                Task { await self.refreshAccess() }
            } catch let error as APIError where error.isRateLimited
                || error.statusCode == 429 {
                Telemetry.shared.track(
                    "coach_turn_failed",
                    properties: ["stage": "rate_limit"]
                )
                self.toast = "请求太频繁，请稍后再试"
            } catch {
                Telemetry.shared.track(
                    "coach_turn_failed",
                    properties: ["stage": "turn"]
                )
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "这次操作没有完成，请重试一次。"
                    )
                )
                self.toast = "教练控制链路暂时不可用"
            }
        }
    }

    /// 训练页内嵌 co-pilot：只保留一条临时回复，不写主聊天。
    /// 需要确认的写操作仍会落到 coachPending，提示用户回教练页确认。
    func askWorkoutCoach(
        _ text: String,
        activeWorkout: [String: Any]? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isWorkoutCoachWorking else { return }
        isWorkoutCoachWorking = true
        workoutCoachReply = nil
        var appContext = agentAppContext()
        if let activeWorkout {
            appContext["active_workout"] = activeWorkout
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isWorkoutCoachWorking = false }
            do {
                let response = try await APIClient.shared.coachTurn(
                    message: trimmed,
                    sessionID: self.coachSessionID,
                    appContext: appContext
                )
                self.coachSessionID = response.session.id
                self.coachSession = response.session
                self.coachPending = response.pending
                if response.pending != nil {
                    self.workoutCoachReply = response.reply
                        + "\n\n这个操作需要回教练页确认。"
                } else {
                    self.workoutCoachReply = response.reply
                }
                self.persist()
            } catch {
                self.workoutCoachReply = "教练暂时没回，先按上一组的感觉练。"
            }
        }
    }

    func confirmCoachPending() {
        guard let pending = coachPending,
              !isCoachControlWorking,
              !isReplying else { return }
        isCoachControlWorking = true
        isReplying = true
        persist()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isCoachControlWorking = false
                self.isReplying = false
                self.persist()
            }
            do {
                let response = try await APIClient.shared.confirmCoachPending(id: pending.id)
                self.coachPending = nil
                self.coachReceipt = response.receipt
                self.coachUndoActionID = response.actionID
                self.scheduleCoachUndoDismissal()
                if pending.capabilityID.hasPrefix("ui.") {
                    self.coachUndoActionID = nil
                    self.coachUndoExpiresAt = nil
                }
                var reminderNotice: String?
                if pending.capabilityID == "ui.start_training",
                   let raw = pending.payload?.dayID,
                   let dayID = UUID(uuidString: raw),
                   let day = self.plan?.days.first(where: { $0.id == dayID }) {
                    self.selectedTab = AppTab.today.rawValue
                    self.workoutLaunchDayID = day.id
                }
                if pending.capabilityID == "ui.open_screen" {
                    self.openCoachScreen(pending.payload?.screen)
                }
                if pending.capabilityID == "ui.configure_reminders" {
                    if let items = pending.payload?.reminderItems, !items.isEmpty {
                        if response.receipt?.enabled == false {
                            for item in items {
                                self.disableHabitReminder(kind: item.kind)
                            }
                        } else {
                            for item in items {
                                let hour = item.hour
                                    ?? response.receipt?.hour
                                    ?? self.reminderHour
                                let minute = item.minute
                                    ?? response.receipt?.minute
                                    ?? self.reminderMinute
                                _ = await self.enableHabitReminder(
                                    kind: item.kind,
                                    hour: hour,
                                    minute: minute
                                )
                            }
                            if !self.notificationsEnabled {
                                reminderNotice = "没有获得通知权限，提醒暂时不会推送。请到「设置 → 通知 → 叫练」中开启。"
                            }
                        }
                    } else {
                        let habitKind = pending.payload?.kind
                        if let habitKind, habitKind != "training" {
                            if response.receipt?.enabled == false {
                                self.disableHabitReminder(kind: habitKind)
                            } else {
                                let hour = response.receipt?.hour
                                    ?? pending.payload?.hour
                                    ?? self.reminderHour
                                let minute = response.receipt?.minute
                                    ?? pending.payload?.minute
                                    ?? self.reminderMinute
                                let scheduled = await self.enableHabitReminder(
                                    kind: habitKind,
                                    hour: hour,
                                    minute: minute
                                )
                                if !self.notificationsEnabled {
                                    reminderNotice = "没有获得通知权限，提醒暂时不会推送。请到「设置 → 通知 → 叫练」中开启。"
                                } else if !scheduled {
                                    reminderNotice = "习惯提醒没有排上，请稍后再试。"
                                }
                            }
                        } else if response.receipt?.enabled == false {
                            self.disableReminders()
                        } else {
                            let hour = response.receipt?.hour
                                ?? pending.payload?.hour
                                ?? self.reminderHour
                            let minute = response.receipt?.minute
                                ?? pending.payload?.minute
                                ?? self.reminderMinute
                            let count = await self.enableReminders(
                                hour: hour,
                                minute: minute
                            )
                            if !self.notificationsEnabled {
                                reminderNotice = "没有获得通知权限，提醒暂时不会推送。请到「设置 → 通知 → 叫练」中开启。"
                            } else if count == 0 {
                                reminderNotice = "通知权限已开启，但当前还没有训练计划。生成计划后会自动安排提醒。"
                            }
                        }
                    }
                }
                if pending.capabilityID == "training.reschedule" {
                    self.applyCoachPlanDate(
                        dayID: pending.payload?.dayID,
                        dateString: pending.payload?.toDate
                    )
                }
                if pending.capabilityID == "body.log_weight" {
                    self.applyCoachWeight(
                        receipt: response.receipt,
                        actionID: response.actionID
                    )
                }
                if pending.capabilityID == "profile.update_goal" {
                    self.applyCoachGoal(pending: pending)
                }
                if let plan = response.plan {
                    if pending.capabilityID == "training.generate_plan"
                        || pending.capabilityID == "training.adjust_plan"
                        || pending.capabilityID == "training.edit_day_exercises"
                        || pending.capabilityID == "training.edit_day_exercise"
                        || pending.capabilityID == "training.add_plan_day" {
                        self.coachPlanBefore = self.plan
                    }
                    self.plan = plan
                    self.planNeedsServerSync = false
                    self.deferredPlanPreview = nil
                    self.rescheduleNotifications()
                }
                if pending.capabilityID == "training.add_plan_day",
                   let raw = pending.payload?.date,
                   let date = FitnessDate.date(from: raw),
                   var updated = self.plan,
                   let dayID = response.receipt?.dayID,
                   let index = updated.days.firstIndex(where: {
                       $0.id.uuidString.lowercased() == dayID.lowercased()
                   }) {
                    updated.days[index].date = FitnessDate.startOfDay(date)
                    updated.days[index].weekday = FitnessDate.weekdayNumber(date)
                    updated.days[index].scheduleUpdatedAt = Date()
                    self.plan = updated
                }
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: response.receipt?.summary ?? "已执行，可以在下方撤销。"
                    )
                )
                if let reminderNotice {
                    self.chat.append(
                        ChatMessage(role: .assistant, text: reminderNotice)
                    )
                }
                let domains = CoachRefreshDomains.domains(
                    for: pending.capabilityID,
                    server: response.refreshDomains
                )
                Task {
                    if domains.contains(.schedule) {
                        await self.pushPlanSchedule()
                    }
                    await self.refreshDomains(domains)
                }
                if pending.capabilityID == "diet.favorite_food"
                    || pending.capabilityID == "diet.custom_food"
                    || pending.capabilityID == "training.dislike_exercise" {
                    Task { await self.syncCloudExtras() }
                }
                if domains.contains(.diet)
                    || domains.contains(.body)
                    || domains.contains(.profile)
                    || domains.contains(.schedule) {
                    self.invalidateNutritionTargetCaches()
                    self.bump([.diet])
                    self.persist()
                    Task { await self.refreshNutritionTargets() }
                }
                Telemetry.shared.track(
                    "coach_pending_confirmed",
                    properties: ["capability": pending.capabilityID]
                )
                self.persist()
            } catch {
                Telemetry.shared.track(
                    "coach_pending_confirm_failed",
                    properties: ["capability": pending.capabilityID]
                )
                self.toast = "执行失败：\(error.localizedDescription)"
            }
        }
    }

    func cancelCoachPending() {
        guard let pending = coachPending, !isCoachControlWorking else { return }
        coachPending = nil
        persist()
        Task { @MainActor in
            Telemetry.shared.track(
                "coach_pending_cancelled",
                properties: ["capability": pending.capabilityID]
            )
        }
        Task {
            try? await APIClient.shared.cancelCoachPending(id: pending.id)
        }
        chat.append(ChatMessage(role: .assistant, text: "已取消这次操作。"))
        persist()
    }

    func undoCoachReceipt() {
        guard let actionID = coachUndoActionID, !isCoachControlWorking else { return }
        let receipt = coachReceipt
        coachUndoDismissTask?.cancel()
        coachUndoDismissTask = nil
        coachUndoExpiresAt = nil
        coachUndoActionID = nil
        coachReceipt = nil
        persist()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await APIClient.shared.undoCoachAction(id: actionID)
                if let receipt, receipt.fromDate != nil {
                    self.applyCoachPlanDate(
                        dayID: receipt.dayID,
                        dateString: receipt.fromDate
                    )
                }
                if receipt?.capabilityID == "body.log_weight" {
                    let date = receipt?.date.flatMap { FitnessDate.date(from: $0) } ?? Date()
                    let key = FitnessDate.key(date)
                    self.bodyMetrics.removeAll { $0.dateKey == key }
                    if let before = self.coachBodyBefore {
                        self.appendBodyMetric(before)
                    } else if let weight = self.coachWeightBefore {
                        self.profile.weightKG = weight
                    }
                    self.coachBodyBefore = nil
                    self.coachWeightBefore = nil
                }
                if receipt?.capabilityID == "training.generate_plan"
                    || receipt?.capabilityID == "training.adjust_plan"
                    || receipt?.capabilityID == "training.edit_day_exercises"
                    || receipt?.capabilityID == "training.edit_day_exercise"
                    || receipt?.capabilityID == "training.add_plan_day" {
                    self.plan = self.coachPlanBefore
                    self.coachPlanBefore = nil
                    self.planNeedsServerSync = false
                    self.rescheduleNotifications()
                }
                let domains = CoachRefreshDomains.domains(
                    for: receipt?.capabilityID ?? "",
                    server: response.refreshDomains
                )
                Task {
                    if domains.contains(.schedule) {
                        await self.pushPlanSchedule()
                    }
                    await self.refreshDomains(domains)
                }
                if receipt?.capabilityID == "diet.favorite_food"
                    || receipt?.capabilityID == "diet.custom_food"
                    || receipt?.capabilityID == "training.dislike_exercise" {
                    Task { await self.syncCloudExtras() }
                }
                if domains.contains(.diet)
                    || domains.contains(.body)
                    || domains.contains(.profile)
                    || domains.contains(.schedule) {
                    self.invalidateNutritionTargetCaches()
                    self.bump([.diet])
                    self.persist()
                    Task { await self.refreshNutritionTargets() }
                }
                self.toast = "已撤销"
                Telemetry.shared.track(
                    "coach_action_undone",
                    properties: ["capability": receipt?.capabilityID ?? "unknown"]
                )
                self.chat.append(
                    ChatMessage(role: .assistant, text: "已撤销刚才的操作。")
                )
                self.persist()
            } catch {
                Telemetry.shared.track(
                    "coach_action_undo_failed",
                    properties: ["capability": receipt?.capabilityID ?? "unknown"]
                )
                self.coachUndoActionID = actionID
                self.coachReceipt = receipt
                // Keep the card until the user retries or taps 完成.
                self.coachUndoExpiresAt = nil
                self.toast = "撤销失败：\(error.localizedDescription)"
            }
        }
    }

    @MainActor
    func restoreCoachControlSession() async {
        guard AuthTokenStore.shared.accessToken != nil,
              !isCoachControlWorking,
              !isReplying else { return }

        // A reinstall/new device has no local session id. Resume the newest
        // server session instead of silently starting from an empty chat.
        if coachSessionID == nil {
            guard let latest = try? await APIClient.shared.latestCoachSession(),
                  let session = latest.session else { return }
            coachSessionID = session.id
            coachSession = session
            coachPending = session.pending
        }

        guard let sessionID = coachSessionID else { return }
        do {
            let state = try await APIClient.shared.coachSession(id: sessionID)
            coachSession = state
            coachPending = state.pending
            if let history = try? await APIClient.shared.coachHistory(sessionID: sessionID) {
                mergeCoachHistory(history.items)
                coachHistoryHasMore = history.hasMore
                coachHistoryCursor = history.nextBeforeID
            }
            persist()
        } catch {
            coachSessionID = nil
            coachPending = nil
            persist()
        }
    }

    func refreshCoachInbox() {
        guard AuthTokenStore.shared.accessToken != nil else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let response = try? await APIClient.shared.coachInbox(limit: 100) {
                self.coachInbox = response.items
            }
        }
    }

    @MainActor
    func loadEarlierCoachHistory() async {
        guard let sessionID = coachSessionID,
              let cursor = coachHistoryCursor,
              coachHistoryHasMore,
              !isLoadingCoachHistory,
              AuthTokenStore.shared.accessToken != nil else { return }
        isLoadingCoachHistory = true
        defer { isLoadingCoachHistory = false }
        do {
            let history = try await APIClient.shared.coachHistory(
                sessionID: sessionID,
                beforeID: cursor
            )
            mergeCoachHistory(history.items)
            coachHistoryHasMore = history.hasMore
            coachHistoryCursor = history.nextBeforeID
            persist()
        } catch {
            toast = "更早的消息加载失败，请稍后重试"
        }
    }

    private func mergeCoachHistory(_ turns: [CoachTurnRecord]) {
        var known = Set(chat.compactMap(\.serverMessageID))
        for turn in turns {
            let userID = "coach-\(turn.id)-user"
            if !turn.inputText.isEmpty, !known.contains(userID) {
                chat.append(
                    ChatMessage(
                        role: .user,
                        text: turn.inputText,
                        date: turn.createdAt ?? Date(),
                        serverMessageID: userID
                    )
                )
                known.insert(userID)
            }
            if let reply = turn.reply, !reply.isEmpty {
                let assistantID = "coach-\(turn.id)-assistant"
                if !known.contains(assistantID) {
                    chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: reply,
                            date: turn.createdAt ?? Date(),
                            isSafety: turn.intent == "safety",
                            serverMessageID: assistantID
                        )
                    )
                    known.insert(assistantID)
                }
            }
        }
        chat = CoachChatOrdering.sorted(chat)
    }

    private func applyCoachWeight(receipt: CoachReceipt?, actionID: String) {
        guard let receipt else { return }
        let hasMetric = receipt.weightKG != nil
            || receipt.bodyFatPCT != nil
            || receipt.waistCM != nil
            || receipt.armCM != nil
            || receipt.thighCM != nil
        guard hasMetric else { return }
        let date = receipt.date.flatMap { FitnessDate.date(from: $0) } ?? Date()
        let key = FitnessDate.key(date)
        coachBodyBefore = bodyMetrics.first { $0.dateKey == key }
        coachWeightBefore = profile.weightKG
        let id = UUID(uuidString: receipt.clientID ?? actionID) ?? UUID()
        appendBodyMetric(
            BodyMetric(
                id: id,
                date: date,
                weightKG: receipt.weightKG,
                bodyFatPCT: receipt.bodyFatPCT,
                waistCM: receipt.waistCM,
                armCM: receipt.armCM,
                thighCM: receipt.thighCM,
                syncedAt: Date()
            )
        )
        persist()
    }

    private func applyCoachPlanDate(dayID: String?, dateString: String?) {
        guard let dayID,
              let dateString,
              let date = FitnessDate.date(from: dateString),
              var updated = plan,
              let index = updated.days.firstIndex(where: {
                  $0.id.uuidString.lowercased() == dayID.lowercased()
              }) else { return }
        let day = FitnessDate.startOfDay(date)
        updated.days[index].date = day
        updated.days[index].weekday = FitnessDate.weekdayNumber(day)
        let start = updated.planStartDate
        let diff = FitnessDate.calendar.dateComponents(
            [.day],
            from: start,
            to: day
        ).day ?? 0
        let week = max(1, diff / 7 + 1)
        updated.days[index].weekIndex = week
        updated.weeks = max(updated.weeks, week)
        updated.days[index].skippedAt = nil
        updated.days[index].scheduleUpdatedAt = Date()
        updated.updatedAt = Date()
        plan = updated
        persist()
    }

    private func openCoachScreen(_ screen: String?) {
        guard let screen else { return }
        switch screen {
        case "today":
            selectedTab = AppTab.today.rawValue
        case "plan":
            selectedTab = AppTab.record.rawValue
        case "coach":
            selectedTab = AppTab.coach.rawValue
        case "equipment":
            selectedTab = AppTab.discover.rawValue
        case "profile":
            selectedTab = AppTab.profile.rawValue
        case "profile_edit":
            selectedTab = AppTab.profile.rawValue
            pendingRoute = .profileEdit
        case "training_schedule":
            selectedTab = AppTab.record.rawValue
            pendingRoute = .trainingSchedule
        case "nutrition":
            selectedTab = AppTab.today.rawValue
            pendingRoute = .nutrition
        case "body_checkin":
            selectedTab = AppTab.today.rawValue
            pendingRoute = .bodyCheckIn
        case "body_analysis":
            selectedTab = AppTab.coach.rawValue
            coachBodyAnalysisRequested = true
        case "equipment_scan":
            selectedTab = AppTab.coach.rawValue
            coachEquipmentScanRequested = true
        case "workout_history":
            selectedTab = AppTab.record.rawValue
            pendingRoute = .workoutHistory
        case "agent_memory":
            selectedTab = AppTab.profile.rawValue
            pendingRoute = .agentMemory
        case "period_schedule":
            selectedTab = AppTab.record.rawValue
            pendingRoute = .periodSchedule
        default:
            break
        }
    }

    private func applyCoachGoal(pending: CoachPendingState) {
        guard let payload = pending.payload else { return }
        if let raw = payload.goalType, let goal = goalType(from: raw) {
            profile.goalType = goal
        }
        if let weight = payload.targetWeightKG {
            profile.targetWeightKG = weight
        }
        if let raw = payload.targetDate,
           let date = FitnessDate.date(from: raw) {
            profile.targetDate = date
        }
        normalizeGoalStart(&profile)
        persist()
    }

    private func goalType(from serverValue: String) -> GoalType? {
        switch serverValue {
        case "lose_fat": return .loseFat
        case "build_muscle": return .buildMuscle
        case "recomp": return .recomp
        case "endurance": return .endurance
        default: return GoalType(rawValue: serverValue)
        }
    }

    func dismissCoachReceipt() {
        coachUndoDismissTask?.cancel()
        coachUndoDismissTask = nil
        coachUndoExpiresAt = nil
        coachReceipt = nil
        coachUndoActionID = nil
        coachBodyBefore = nil
        coachWeightBefore = nil
    }

    private func scheduleCoachUndoDismissal() {
        coachUndoDismissTask?.cancel()
        // VoiceOver users need to read the receipt before choosing undo.
        guard !UIAccessibility.isVoiceOverRunning else {
            coachUndoExpiresAt = nil
            coachUndoDismissTask = nil
            return
        }
        let deadline = Date().addingTimeInterval(5)
        coachUndoExpiresAt = deadline
        coachUndoDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled, let self else { return }
            guard let expiry = self.coachUndoExpiresAt,
                  Date() >= expiry else { return }
            self.dismissCoachReceipt()
        }
    }
}
