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
}
