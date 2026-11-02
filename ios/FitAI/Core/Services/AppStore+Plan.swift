import Foundation

extension AppStore {
    func generatePlan(
        force: Bool = true,
        weeklyWeekdays: [Int]? = nil,
        onboarding: Bool = false
    ) {
        guard profile.isOnboarded else { return }
        guard hasPlanEquipment else {
            toast = "请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索"
            return
        }
        guard !isGenerating else { return }
        if !onboarding && !hasProAccess {
            requestPro(.trainingPlan)
            return
        }
        if !onboarding,
           let last = lastPlanGeneratedAt,
           Date().timeIntervalSince(last) < 60 {
            toast = "计划刚刚生成，请稍后再试"
            return
        }
        if plan != nil && !force { return }

        isGenerating = true
        let snapshot = profile
        let librarySlugs = equipmentSlugsForPlan
        let focusAreas = planFocusAreas

        if canUseRemoteAI && weeklyWeekdays == nil {
            let idempotencyKey = pendingPlanIdempotencyKey ?? UUID().uuidString
            pendingPlanIdempotencyKey = idempotencyKey
            Task { @MainActor in
                do {
                    var generated = try await self.planGeneration.generateRemote(
                        profile: snapshot,
                        equipmentSlugs: librarySlugs,
                        focusAreas: focusAreas,
                        force: force,
                        onboarding: onboarding,
                        idempotencyKey: idempotencyKey
                    )
                    generated.version = max(generated.version, (self.plan?.version ?? 0) + 1)
                    self.pendingPlanIdempotencyKey = nil
                    self.archiveCurrentPlan()
                    self.plan = generated
                    self.toast = "已由 AI 生成计划"
                    self.lastPlanGeneratedAt = Date()
                    if onboarding {
                        await self.consumeOnboardingTrialIfNeeded()
                    }
                    await self.refreshAccess()
                } catch let error as APIError where error.statusCode == 429 {
                    self.isGenerating = false
                    if error.code == "GENERATION_IN_PROGRESS" {
                        self.toast = "计划正在生成中，请稍后查看"
                    } else if let retry = error.retryAfter, retry > 0 {
                        self.toast = "计划刚刚生成，请 \(retry) 秒后再试"
                    } else {
                        self.toast = "计划生成太频繁，请稍后再试"
                    }
                    return
                } catch let error as APIError
                    where error.isProRequired || (error.statusCode == 403 && error.code == nil) {
                    self.isGenerating = false
                    if self.hasProAccess {
                        self.toast = "计划服务暂时不可用，请稍后重试"
                    } else {
                        self.requestPro(.trainingPlan)
                    }
                    return
                } catch {
                    var fallback = self.planGeneration.generateLocal(
                        profile: snapshot,
                        dislikedSlugs: self.dislikedSlugs,
                        equipmentSlugs: librarySlugs,
                        weeklyWeekdays: weeklyWeekdays,
                        focusAreas: focusAreas
                    )
                    fallback.version = (self.plan?.version ?? 0) + 1
                    self.archiveCurrentPlan()
                    self.plan = fallback
                    self.toast = "AI 服务不可用，已使用本地模板"
                    self.lastPlanGeneratedAt = Date()
                    if onboarding {
                        await self.consumeOnboardingTrialIfNeeded()
                    }
                }
                self.isGenerating = false
                self.persist()
                self.rescheduleNotifications()
                self.syncPendingUserData()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            var generated = self.planGeneration.generateLocal(
                profile: snapshot,
                dislikedSlugs: self.dislikedSlugs,
                equipmentSlugs: librarySlugs,
                weeklyWeekdays: weeklyWeekdays,
                focusAreas: focusAreas
            )
            generated.version = (self.plan?.version ?? 0) + 1
            self.archiveCurrentPlan()
            self.plan = generated
            self.lastPlanGeneratedAt = Date()
            self.isGenerating = false
            self.persist()
            self.rescheduleNotifications()
            self.syncPendingUserData()
            if onboarding {
                Task { @MainActor in
                    await self.consumeOnboardingTrialIfNeeded()
                }
            }
        }
    }

    func requestPro(_ feature: ProFeature) {
        access.requestPro(feature)
    }

    @discardableResult
    func requirePro(_ feature: ProFeature) -> Bool {
        access.requirePro(feature)
    }

    @MainActor
    func refreshAccess() async {
        await access.refresh()
    }

    @MainActor
    func consumeOnboardingTrialIfNeeded() async {
        try? await APIClient.shared.syncProfile(profile)
        try? await APIClient.shared.syncGoal(profile)
        await access.consumeOnboardingTrial()
    }

    func rescheduleNotifications() {
        guard notificationsEnabled else { return }
        Task { @MainActor in
            _ = await NotificationScheduler.shared.schedule(
                plan: self.plan,
                hour: self.reminderHour,
                minute: self.reminderMinute
            )
        }
    }

    func restorePlan(_ archived: TrainingPlan) {
        guard archived.id != plan?.id else { return }
        archiveCurrentPlan()
        planHistory.removeAll { $0.id == archived.id }
        plan = archived
        toast = "已恢复计划 v\(archived.version)"
        persist()
        rescheduleNotifications()
        syncPendingUserData()
    }

    func archiveCurrentPlan() {
        guard let current = plan else { return }
        // 计划版本变化后训练日 ID 会变化，旧草稿无法安全恢复。
        workoutDraft = nil
        guard planHistory.first?.id != current.id else { return }
        planHistory.insert(current, at: 0)
        if planHistory.count > 5 {
            planHistory.removeLast(planHistory.count - 5)
        }
    }
}
