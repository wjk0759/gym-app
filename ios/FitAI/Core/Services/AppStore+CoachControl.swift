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

    func canRouteToCoachControl(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }

        let deleteVerb = value.range(
            of: #"删掉|删除|去掉|移除"#,
            options: .regularExpression
        ) != nil
        let editVerb = value.range(
            of: #"改成|改为|修正|应该是|改一下|调整"#,
            options: .regularExpression
        ) != nil
        let foodWords = value.range(
            of: #"早餐|午饭|午餐|晚饭|晚餐|加餐|夜宵|吃了|喝的|食物|鸡|牛|猪|鱼|蛋|奶|饭|面|菜|果|肉"#,
            options: .regularExpression
        ) != nil
        if foodWords && (deleteVerb || editVerb) {
            return true
        }
        let workoutWords = value.range(
            of: #"训练记录|跑步|有氧|运动|时长|分钟|组|重量|kg|公斤"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        let bodyWords = value.range(
            of: #"体重|体脂|腰围|臂围|腿围|身体"#,
            options: .regularExpression
        ) != nil
        if workoutWords && (deleteVerb || editVerb) && !bodyWords {
            return true
        }
        let planShape = value.range(
            of: #"每周\s*\d|[1-5]\s*分化|推拉腿|周[一二三四五六日天].*周[一二三四五六日天]"#,
            options: .regularExpression
        ) != nil
        let planMinutes = value.range(
            of: #"\d{2,3}\s*分钟"#,
            options: .regularExpression
        ) != nil
        if planShape && (value.contains("计划") || value.contains("每周") || value.contains("分化")) {
            return true
        }
        if planMinutes && value.contains("计划") && (editVerb || value.contains("安排") || value.contains("调")) {
            return true
        }
        if value.range(
            of: #"开始训练|开始今天|带我练|开始练|练起来|开始今天的训练"#,
            options: .regularExpression
        ) != nil {
            return true
        }
        if value.range(
            of: #"打开|进入|跳到|去一下"#,
            options: .regularExpression
        ) != nil,
           value.range(
               of: #"训练记录|训练历史|训练安排|日程|饮食|身体|体型|设置|档案|计划|教练|器械|记忆|经期|今天"#,
               options: .regularExpression
           ) != nil {
            return true
        }

        let reschedule = value.range(
            of: #"改到|改期|顺延|换到|挪到|调到"#,
            options: .regularExpression
        ) != nil
        let hasDate = value.range(
            of: #"周[一二三四五六日天]|星期[一二三四五六日天]|今天|明天|后天|\d{1,2}月\d{1,2}[日号]|\d{4}[-/.]\d{1,2}[-/.]\d{1,2}"#,
            options: .regularExpression
        ) != nil
        if reschedule && hasDate { return true }

        let dayStrategy = value.range(
            of: #"均衡|碳循环|低碳|高蛋白|地中海|素食|16:8|168|轻断食"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"今天|明天|后天|昨天|周[一二三四五六日天]|星期[一二三四五六日天]|礼拜[一二三四五六日天]|\d{1,2}月\d{1,2}[日号]"#,
                options: .regularExpression
            ) != nil
            && value.range(
                of: #"改成|换成|改为|调整|餐单|饮食"#,
                options: .regularExpression
            ) != nil
        if dayStrategy {
            return true
        }

        let weekDiet = value.range(
            of: #"一周|本周|这周|下周|周计划|7\s*天|七天"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"饮食|餐|营养"#,
                options: .regularExpression
            ) != nil
            && value.range(
                of: #"怎么样|复盘|总结|吃了什么|缺什么|多少"#,
                options: .regularExpression
            ) == nil
            && value.range(
                of: #"排|安排|生成|做|计划|餐单|食谱"#,
                options: .regularExpression
            ) != nil
        if weekDiet {
            return true
        }

        let planEdit = value.range(
            of: #"(?:改|修改|调整).{0,8}(?:训练)?计划|(?:训练)?计划.{0,8}(?:改|修改|调整)"#,
            options: .regularExpression
        ) != nil
        let weekSchedule = value.range(
            of: #"下周|本周|这周|一周|上周"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"练什么|训练安排|计划|日程|安排"#,
                options: .regularExpression
            ) != nil
            && value.range(
                of: #"复盘|完成率|怎么样|总结|状态|饮食|餐|营养|食谱|餐单"#,
                options: .regularExpression
            ) == nil
        if weekSchedule {
            return true
        }

        let addDay = value.range(
            of: #"加一次|加个|加一天|补一次|想练|额外练|加练"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"胸|背|腿|肩|手臂|全身|上肢|下肢"#,
                options: .regularExpression
            ) != nil
        if addDay {
            return true
        }

        let batchParts = value.components(
            separatedBy: CharacterSet(charactersIn: "，,；;")
        )
        let batchCount = batchParts.filter { part in
            part.range(
                of: #"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|臂屈伸|腿举|推胸|蝴蝶机|夹胸|侧平举|后束|卷腹|臀桥"#,
                options: .regularExpression
            ) != nil
                && part.range(
                    of: #"改成|加到|调到|重量|休息|每组|\d+\s*(?:组|次|kg|公斤)"#,
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
        }.count
        if batchCount >= 2 {
            return true
        }

        let exerciseName = value.range(
            of: #"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|臂屈伸|腿举|推胸|蝴蝶机|夹胸|侧平举|后束|卷腹|臀桥"#,
            options: .regularExpression
        ) != nil
        let changeVerb = value.range(
            of: #"换成|替换成|替换为|改成|加到|调到|删掉|去掉|删除|加上|加一个|加个|增加|再加"#,
            options: .regularExpression
        ) != nil
        let paramVerb = value.range(
            of: #"组|次|kg|公斤|秒"#,
            options: .regularExpression
        ) != nil && value.range(
            of: #"重量|休息|每组"#,
            options: .regularExpression
        ) != nil
        let hasList = value.range(
            of: #"[、,，;；/]"#,
            options: .regularExpression
        ) != nil
        let hasHardList = value.range(
            of: #"[、/]"#,
            options: .regularExpression
        ) != nil
        let planWithComma = value.range(
            of: #"计划|训练"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"[，,；;]"#,
                options: .regularExpression
            ) != nil
            && value.range(
                of: #"改成|换成|替换|加"#,
                options: .regularExpression
            ) != nil
        let exerciseEdit = value.range(
            of: #"改成|换成|换为|替换为|替换成"#,
            options: .regularExpression
        ) != nil
            && value.range(
                of: #"计划|训练|练胸|练背|练腿|练肩|练手臂|胸|背|腿|肩|手臂"#,
                options: .regularExpression
            ) != nil
            && hasList
        if exerciseName && !hasHardList && !planWithComma && (changeVerb || paramVerb) {
            return true
        }
        if exerciseEdit {
            return true
        }
        let planEditReschedule = value.range(
            of: #"改到|改期|顺延|挪到|换到|调到"#,
            options: .regularExpression
        ) != nil
        if planEdit && !planEditReschedule {
            return true
        }

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

        if value.range(
            of: #"排.*餐|安排.*餐|安排.*饮食|饮食.*安排|饮食计划|餐单|食谱|明天吃什么|今天吃什么|一周.*餐"#,
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
            of: #"计划餐|按计划吃|跳过.*(早餐|午餐|晚餐|加餐)|恢复.*(早餐|午餐|晚餐|加餐)|换一餐|换餐|体重|称重|体脂|腰围|臂围|手臂围|腿围|大腿围"#,
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
        let negativeFood = value.range(
            of: #"不想吃|没吃|不吃|吃不下|没胃口|不想喝|没喝"#,
            options: .regularExpression
        ) != nil
        return (foodWord || amount) && !negativeFood
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
                self.scheduleCoachUndoDismissal()
                if pending.capabilityID.hasPrefix("ui.") {
                    self.coachUndoActionID = nil
                    self.coachUndoExpiresAt = nil
                }
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
                if domains.contains(.diet) {
                    Task { await self.refreshDailyNutritionTargets() }
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
                if domains.contains(.diet) {
                    Task { await self.refreshDailyNutritionTargets() }
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
        guard let sessionID = coachSessionID,
              AuthTokenStore.shared.accessToken != nil,
              !isCoachControlWorking,
              !isReplying else { return }
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
        if let start = updated.date(week: 1, weekday: 1) {
            let diff = FitnessDate.calendar.dateComponents(
                [.day],
                from: start,
                to: day
            ).day ?? 0
            let week = max(1, diff / 7 + 1)
            updated.days[index].weekIndex = week
            updated.weeks = max(updated.weeks, week)
        }
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
