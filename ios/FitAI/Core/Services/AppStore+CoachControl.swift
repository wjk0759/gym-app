import Foundation

/// New server-owned coach control plane.
///
/// The legacy `sendAgentChat` path stays available for capabilities not yet
/// migrated. Only food logging and training rescheduling route here for now.
extension AppStore {
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
        if value.range(
            of: #"复盘|本周总结|这周状态|周报"#,
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
        let foodWord = value.range(
            of: #"记|吃|喝|餐|零食|夜宵|鸡|牛|猪|鱼|蛋|奶|饭|面|肠|菜|果"#,
            options: .regularExpression
        ) != nil
        let amount = value.range(
            of: #"\d+(?:\.\d+)?\s*(g|克|ml|毫升|杯|份|碗|个|片|勺|盒|瓶)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
        return foodWord || amount
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
                self.coachSessionID = response.session.id
                self.coachSession = response.session
                self.coachPending = response.pending
                self.chat.append(
                    ChatMessage(role: .assistant, text: response.reply)
                )
                self.persist()
            } catch {
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
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: response.receipt?.summary ?? "已执行，可以在下方撤销。"
                    )
                )
                self.syncPendingUserData()
                self.refreshWeeklyReview(force: true)
                Task { await self.refreshDailyNutritionTargets() }
                self.persist()
            } catch {
                self.toast = "执行失败：\(error.localizedDescription)"
            }
        }
    }

    func cancelCoachPending() {
        guard let pending = coachPending, !isCoachControlWorking else { return }
        coachPending = nil
        persist()
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
                self.syncPendingUserData()
                self.refreshWeeklyReview(force: true)
                Task { await self.refreshDailyNutritionTargets() }
                self.toast = "已撤销"
                self.chat.append(
                    ChatMessage(role: .assistant, text: "已撤销刚才的操作。")
                )
                self.persist()
            } catch {
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
            if let response = try? await APIClient.shared.coachInbox() {
                self.coachInbox = response.items
            }
        }
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
