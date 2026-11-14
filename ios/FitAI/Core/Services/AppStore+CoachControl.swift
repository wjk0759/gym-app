import Foundation

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

    func canRouteToCoachControl(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let reschedule = value.range(
            of: #"改到|改期|顺延|换到|挪到|调到"#,
            options: .regularExpression
        ) != nil
        let hasDate = value.range(
            of: #"周[一二三四五六日天]|星期[一二三四五六日天]|今天|明天|后天|\d{1,2}月\d{1,2}[日号]|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}"#,
            options: .regularExpression
        ) != nil
        if reschedule && hasDate { return true }

        let correction = value.range(
            of: #"记错|不是|改成|应该是|修正|改一下"#,
            options: .regularExpression
        ) != nil
        if correction {
            let active = coachSession?.activeTopic
            if let active, active != "review.weekly" {
                return true
            }
            if value.range(
                of: #"(kg|公斤|斤)"#,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                return true
            }
        }

        if value.range(
            of: #"复盘|本周总结|这周状态|周报"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if value.range(
            of: #"生成.*计划|重新.*计划|重排.*计划|4周计划|新的训练计划"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if value.range(
            of: #"调整.*计划|计划.*调整|减量|加量|降低重量"#,
            options: .regularExpression
        ) != nil,
           value.range(
               of: #"计划|训练"#,
               options: .regularExpression
           ) != nil {
            return true
        }

        let dietReview = value.range(
            of: #"饮食|吃了|摄入|热量|卡路里|蛋白|营养|碳水|脂肪"#,
            options: .regularExpression
        ) != nil
        let dietQuestion = value.range(
            of: #"多少|什么|怎么样|如何|够|缺|看看|总结|复盘|超"#,
            options: .regularExpression
        ) != nil
        let weeklyReview = value.range(
            of: #"本周|这周|一周|周报"#,
            options: .regularExpression
        ) != nil
        if dietReview && dietQuestion && !weeklyReview {
            return true
        }

        let bodyReview = value.range(
            of: #"体重|体脂|腰围|身体|身材|目标进度"#,
            options: .regularExpression
        ) != nil
        let bodyQuestion = value.range(
            of: #"变化|趋势|怎么样|怎么|如何|进度|最近|几周|吗|？|\?"#,
            options: .regularExpression
        ) != nil
        if bodyReview && bodyQuestion {
            return true
        }

        if value.range(
            of: #"练什么|练哪|下一练|下次训练|训练安排|接下来.*练"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if value.range(
            of: #"多少|热量|卡路里|为什么|怎么|吗|？|\?"#,
            options: .regularExpression
        ) != nil {
            return false
        }

        if value.range(
            of: #"计划餐|按计划吃|跳过.*(早餐|午餐|晚餐|加餐)|恢复.*(早餐|午餐|晚餐|加餐)|换一餐|换餐|体重|称重"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if value.range(
            of: #"目标|减脂|减肥|增肌|塑形|重塑|耐力|体能"#,
            options: .regularExpression
        ) != nil,
           value.range(
               of: #"\d|月|日"#,
               options: .regularExpression
           ) != nil {
            return true
        }

        if value.range(
            of: #"跑|骑车|单车|自行车|游泳|快走|走路|划船|有氧"#,
            options: .regularExpression
        ) != nil,
           value.range(
               of: #"\d+(?:\.\d+)?\s*(分钟|min|小时|h)"#,
               options: [.regularExpression, .caseInsensitive]
           ) != nil {
            return true
        }

        if value.range(
            of: #"跳过.*训练|不练了|少练一次|休息一天|今天休息"#,
            options: .regularExpression
        ) != nil {
            return true
        }

        if value.range(
            of: #"体重|称重"#,
            options: .regularExpression
        ) == nil,
           value.range(
               of: #"\d+(?:\.\d+)?\s*(kg|公斤|斤)"#,
               options: [.regularExpression, .caseInsensitive]
           ) != nil,
           value.range(
               of: #"\d+\s*(组|次|个|reps?)"#,
               options: [.regularExpression, .caseInsensitive]
           ) != nil {
            return true
        }
        let foodWord = value.range(
            of: #"吃|喝|餐|零食|夜宵|记录饮食|记饮食|鸡|牛|猪|鱼|蛋|奶|饭|面|肠|菜|果"#,
            options: .regularExpression
        ) != nil
        let amount = value.range(
            of: #"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return foodWord || amount
    }

    /// Route conversational text to the control-plane answer capability.
    ///
    /// Action-heavy requests stay on the legacy agent until their specific
    /// capabilities are migrated. Recognized writes are already intercepted by
    /// `canRouteToCoachControl` before this check.
    func shouldUseCoachFreeChat(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        let action = value.range(
            of: #"改成|换成|换一个|换个|替换|调整|修改|删掉|删除|增加|减少|生成|重排|安排|记录|记一下|帮我记|保存|计划餐|改到|改期|顺延|挪到"#,
            options: .regularExpression
        ) != nil
        if action { return false }
        let question = value.range(
            of: #"吗|？|\?|怎么|如何|为什么|能不能|可不可以|要不要|该不该|推荐|建议|什么是|多少|几天|多久"#,
            options: .regularExpression
        ) != nil
        if question { return true }
        return value.count <= 40
            && value.range(
                of: #"我|今天|最近|感觉|有点|没|不想|吃|睡|累|疼|酸|练"#,
                options: .regularExpression
            ) != nil
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
                if let plan = response.plan {
                    if pending.capabilityID == "training.generate_plan"
                        || pending.capabilityID == "training.adjust_plan" {
                        self.coachPlanBefore = self.plan
                    }
                    self.plan = plan
                    self.planNeedsServerSync = false
                    self.deferredPlanPreview = nil
                    self.rescheduleNotifications()
                }
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: response.receipt?.summary ?? "已执行，可以在下方撤销。"
                    )
                )
                self.syncPendingUserData()
                self.refreshWeeklyReview(force: true)
                Task { await self.refreshDailyNutritionTargets() }
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
        coachUndoActionID = nil
        coachReceipt = nil
        persist()
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await APIClient.shared.undoCoachAction(id: actionID)
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
                    || receipt?.capabilityID == "training.adjust_plan" {
                    self.plan = self.coachPlanBefore
                    self.coachPlanBefore = nil
                    self.planNeedsServerSync = false
                    self.rescheduleNotifications()
                }
                self.syncPendingUserData()
                self.refreshWeeklyReview(force: true)
                Task { await self.refreshDailyNutritionTargets() }
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
                self.toast = "撤销失败：\(error.localizedDescription)"
            }
        }
    }

    func restoreCoachControlSession() {
        guard let sessionID = coachSessionID,
              AuthTokenStore.shared.accessToken != nil,
              !isCoachControlWorking,
              !isReplying else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let state = try await APIClient.shared.coachSession(id: sessionID)
                self.coachSession = state
                self.coachPending = state.pending
                if let history = try? await APIClient.shared.coachHistory(sessionID: sessionID) {
                    self.mergeCoachHistory(history.items)
                    self.coachHistoryHasMore = history.hasMore
                    self.coachHistoryCursor = history.nextBeforeID
                }
                self.persist()
            } catch {
                self.coachSessionID = nil
                self.coachPending = nil
                self.persist()
            }
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

    func loadEarlierCoachHistory() {
        guard let sessionID = coachSessionID,
              let cursor = coachHistoryCursor,
              coachHistoryHasMore,
              !isLoadingCoachHistory,
              AuthTokenStore.shared.accessToken != nil else { return }
        isLoadingCoachHistory = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoadingCoachHistory = false }
            do {
                let history = try await APIClient.shared.coachHistory(
                    sessionID: sessionID,
                    beforeID: cursor
                )
                self.mergeCoachHistory(history.items)
                self.coachHistoryHasMore = history.hasMore
                self.coachHistoryCursor = history.nextBeforeID
                self.persist()
            } catch {
                self.toast = "更早的消息加载失败，请稍后重试"
            }
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
        chat.sort { $0.date < $1.date }
    }

    private func applyCoachWeight(receipt: CoachReceipt?, actionID: String) {
        guard let weight = receipt?.weightKG else { return }
        let date = receipt?.date.flatMap { FitnessDate.date(from: $0) } ?? Date()
        let key = FitnessDate.key(date)
        coachBodyBefore = bodyMetrics.first { $0.dateKey == key }
        coachWeightBefore = profile.weightKG
        let id = UUID(uuidString: receipt?.clientID ?? actionID) ?? UUID()
        appendBodyMetric(
            BodyMetric(
                id: id,
                date: date,
                weightKG: weight,
                bodyFatPCT: nil,
                waistCM: nil,
                armCM: nil,
                thighCM: nil,
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
        updated.days[index].date = date
        updated.days[index].scheduleUpdatedAt = Date()
        updated.updatedAt = Date()
        plan = updated
        persist()
    }
}
