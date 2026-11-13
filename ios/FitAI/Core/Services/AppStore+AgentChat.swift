import Foundation

extension AppStore {
    func sendChat(_ text: String, skill: CoachSkill = .trainer) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Free accounts must hit /agent/chat so the server can consume the
        // daily quota. Local replies are only for Pro users who explicitly
        // turned remote AI off.
        guard CoachChatPolicy.transport(
            hasPro: hasProAccess,
            remoteEnabled: useRemoteAI
        ) == .local else {
            sendAgentChat(trimmed, skill: skill)
            return
        }

        cancelActiveChatRequest()
        removeTrailingChatTimeoutNotices()
        lastAgentRetryText = nil
        chat.append(ChatMessage(role: .user, text: trimmed))
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
        if !agentActions.isEmpty {
            dismissAgentActions()
        }
        if pendingDraft != nil {
            cancelPendingDraft()
        }
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

    /// 服务端保存最近一张待确认卡和草稿；换设备或重装后可恢复。
    func restoreAgentPendingState() {
        guard AuthTokenStore.shared.accessToken != nil,
              CoachChatPolicy.transport(
                  hasPro: hasProAccess,
                  remoteEnabled: useRemoteAI
              ) == .agent,
              !isReplying,
              !isExecutingAgentActions else { return }
        let accountID = currentUserID
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let state = try await APIClient.shared.agentPendingState()
                guard self.currentUserID == accountID,
                      !self.isReplying,
                      !self.isExecutingAgentActions else { return }
                if let proposal = state.proposal {
                    if self.agentProposal == nil {
                        self.agentProposal = proposal
                        if let sessionID = state.sessionID {
                            self.agentSessionID = sessionID
                        }
                    }
                } else if self.agentProposal != nil {
                    self.agentProposal = nil
                }
                if let card = state.pendingAction, !card.actions.isEmpty {
                    if self.agentActions.isEmpty {
                        self.agentSessionID = state.sessionID
                        self.agentRunID = card.runID
                        self.agentActions = card.actions
                    }
                    if self.pendingDraft == nil {
                        self.pendingDraft = state.pendingDraft
                    }
                    self.persist()
                    return
                }
                if !self.agentActions.isEmpty {
                    // 其他设备已确认/忽略，本地卡片不能继续执行。
                    self.agentActions = []
                    self.agentRunID = nil
                }
                if let draft = state.pendingDraft {
                    if let sessionID = state.sessionID {
                        self.agentSessionID = sessionID
                    }
                    if self.pendingDraft == nil {
                        self.pendingDraft = draft
                    }
                } else if self.pendingDraft != nil {
                    self.pendingDraft = nil
                }
                self.persist()
            } catch {
                // 网络不可用时保留本地持久化的卡和草稿。
            }
        }
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

        let pendingActions = agentActions
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
                let context = self.agentAppContext(pendingActions: pendingActions)
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
                self.pendingDraft = response.pendingDraft
                var assistant = ChatMessage(
                    role: .assistant,
                    text: response.reply,
                    isSafety: response.safetyFlag != nil
                )
                assistant.serverMessageID = response.messageID
                assistant.serverRunID = response.runID
                self.chat.append(assistant)
                self.lastAgentRetryText = nil
                self.lastAgentRequestID = nil
                if response.safetyFlag == nil {
                    self.coachQuotaExhausted = false
                }
                Task { await self.refreshAccess() }
            } catch is CancellationError {
                return
            } catch let error as APIError where error.isCoachQuotaExhausted {
                await self.refreshAccess()
                self.agentActions = pendingActions
                self.coachQuotaExhausted = true
                return
            } catch let error as APIError where error.isRateLimited || error.statusCode == 429 {
                self.agentActions = pendingActions
                self.toast = "请求太频繁，请稍后再试"
                return
            } catch let error as APIError where error.isProRequired {
                self.agentActions = pendingActions
                await self.refreshAccess()
                if self.hasProAccess || (self.access.policy.coachRemaining ?? 0) > 0 {
                    // A text coach turn must never open the coach paywall while
                    // the daily free quota is still available.
                    self.lastAgentRetryText = trimmed
                    self.lastAgentRetrySkill = skill
                    self.toast = "这次请求没有发送成功，请稍后重试"
                } else {
                    self.requestPro(.coachAI)
                }
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.agentActions = pendingActions
                guard !self.shouldShowCoachQuotaCard else {
                    self.toast = "网络暂时不可用，请稍后重试"
                    return
                }
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
    func cancelPendingDraft() {
        guard let draft = pendingDraft else { return }
        pendingDraft = nil
        chat.append(
            ChatMessage(role: .assistant, text: "已取消这次记录。")
        )
        persist()
        Task {
            try? await APIClient.shared.deleteAgentDraft(id: draft.id)
        }
    }

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
