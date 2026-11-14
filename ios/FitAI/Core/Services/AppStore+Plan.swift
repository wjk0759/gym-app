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
        guard workoutDraft == nil else {
            toast = "你正在训练；请先保存或结束当前训练，再重新生成计划"
            return
        }
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
        let strictEquipment = strictEquipmentMode
        let focusAreas = planFocusAreas

        if (canUseRemoteAI || onboarding) && weeklyWeekdays == nil {
            let idempotencyKey = pendingPlanIdempotencyKey ?? UUID().uuidString
            pendingPlanIdempotencyKey = idempotencyKey
            Task { @MainActor in
                // The server owns the candidate pool, so the equipment
                // library must be current before it can plan.
                let equipmentSynced = await self.syncEquipmentForPlanGeneration()
                guard equipmentSynced else {
                    await self.applyLocalPlanFallback(
                        profile: snapshot,
                        equipmentSlugs: librarySlugs,
                        strictEquipment: strictEquipment,
                        weeklyWeekdays: weeklyWeekdays,
                        focusAreas: focusAreas,
                        onboarding: onboarding,
                        toast: "器械库未同步，已使用本地模板"
                    )
                    self.isGenerating = false
                    self.persist()
                    self.rescheduleNotifications()
                    return
                }

                do {
                    var generated = try await self.planGeneration.generateRemote(
                        profile: snapshot,
                        strictEquipment: strictEquipment,
                        focusAreas: focusAreas,
                        force: force,
                        onboarding: onboarding,
                        idempotencyKey: idempotencyKey
                    )
                    generated.version = max(generated.version, (self.plan?.version ?? 0) + 1)
                    self.pendingPlanIdempotencyKey = nil
                    if onboarding, self.plan == nil {
                        self.pendingPlanPreview = generated
                        self.planNeedsServerSync = false
                        self.toast = "计划已生成，确认后开始"
                    } else {
                        self.archiveCurrentPlan()
                        self.plan = generated
                        self.planNeedsServerSync = false
                        self.toast = generated.generatedBy == "ai"
                            ? "已由 AI 生成计划"
                            : "已用规则模板生成计划"
                    }
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
                } catch let error as APIError where error.isProRequired {
                    self.isGenerating = false
                    await self.refreshAccess()
                    self.requestPro(.trainingPlan)
                    return
                } catch let error as APIError
                    where error.statusCode == 403 && error.code == nil {
                    self.isGenerating = false
                    self.toast = "计划服务暂时不可用，请稍后重试"
                    return
                } catch let error as APIError where error.statusCode == 422 {
                    await self.applyLocalPlanFallback(
                        profile: snapshot,
                        equipmentSlugs: librarySlugs,
                        strictEquipment: strictEquipment,
                        weeklyWeekdays: weeklyWeekdays,
                        focusAreas: focusAreas,
                        onboarding: onboarding,
                        toast: error.message
                    )
                } catch {
                    await self.applyLocalPlanFallback(
                        profile: snapshot,
                        equipmentSlugs: librarySlugs,
                        strictEquipment: strictEquipment,
                        weeklyWeekdays: weeklyWeekdays,
                        focusAreas: focusAreas,
                        onboarding: onboarding,
                        toast: "网络或服务异常，已使用本地模板"
                    )
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
                strictEquipment: strictEquipment,
                weeklyWeekdays: weeklyWeekdays,
                focusAreas: focusAreas,
                sessions: self.sessions,
                planWeights: self.planWeightTargets
            )
            generated.version = (self.plan?.version ?? 0) + 1
            if onboarding, self.plan == nil {
                self.pendingPlanPreview = generated
                self.planNeedsServerSync = true
                self.toast = "计划已生成，确认后开始"
            } else {
                self.archiveCurrentPlan()
                self.plan = generated
                self.planNeedsServerSync = true
            }
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

    /// Builds the local plan when the remote path cannot run, and explains why
    /// instead of blaming the AI service for every failure.
    @MainActor
    private func applyLocalPlanFallback(
        profile snapshot: UserProfile,
        equipmentSlugs: [String],
        strictEquipment: Bool,
        weeklyWeekdays: [Int]?,
        focusAreas: Set<BodyFocusArea>,
        onboarding: Bool,
        toast message: String
    ) async {
        var fallback = planGeneration.generateLocal(
            profile: snapshot,
            dislikedSlugs: dislikedSlugs,
            equipmentSlugs: equipmentSlugs,
            strictEquipment: strictEquipment,
            weeklyWeekdays: weeklyWeekdays,
            focusAreas: focusAreas,
            sessions: sessions,
            planWeights: planWeightTargets
        )
        fallback.version = (plan?.version ?? 0) + 1
        if onboarding, plan == nil {
            pendingPlanPreview = fallback
            planNeedsServerSync = true
            toast = "计划已用本地模板生成，确认后开始"
        } else {
            archiveCurrentPlan()
            plan = fallback
            planNeedsServerSync = true
            toast = message
        }
        lastPlanGeneratedAt = Date()
        if onboarding {
            await consumeOnboardingTrialIfNeeded()
        }
    }

    /// Last manually edited or generated target weight per exercise, used only
    /// when there is no real workout set to anchor the next plan.
    var planWeightTargets: [String: Double] {
        var plans: [TrainingPlan] = []
        if let plan { plans.append(plan) }
        plans.append(contentsOf: planHistory)
        var result: [String: Double] = [:]
        for plan in plans {
            for day in plan.days {
                for exercise in day.exercises {
                    guard result[exercise.slug] == nil,
                          let weight = exercise.weightKG,
                          weight > 0 else { continue }
                    result[exercise.slug] = weight
                }
            }
        }
        return result
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
        if access.policy.isPro || (access.snapshot?.coachRemaining ?? 0) > 0 {
            coachQuotaExhausted = false
        }
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
        guard workoutDraft == nil else {
            toast = "你正在训练；请先保存或结束当前训练，再恢复旧计划"
            return
        }
        archiveCurrentPlan()
        planHistory.removeAll { $0.id == archived.id }
        var restored = archived
        restored.version += 1
        restored.updatedAt = Date()
        plan = restored
        planNeedsServerSync = true
        toast = "已恢复计划 v\(restored.version)"
        persist()
        rescheduleNotifications()
        syncPendingUserData()
    }

    func deferPendingPlan() {
        guard let pending = pendingPlanPreview else { return }
        deferredPlanPreview = pending
        pendingPlanPreview = nil
        persist()
    }

    func resumeDeferredPlan() {
        guard let deferred = deferredPlanPreview else { return }
        deferredPlanPreview = nil
        pendingPlanPreview = deferred
        persist()
    }

    func confirmPendingPlan(openRecord: Bool = false) {
        guard let pending = pendingPlanPreview else { return }
        guard workoutDraft == nil else {
            toast = "你正在训练；请先保存或结束当前训练，再开始新计划"
            return
        }
        let needsServerImport = planNeedsServerSync
        pendingPlanPreview = nil
        deferredPlanPreview = nil
        Task { @MainActor in
            if !needsServerImport {
                do {
                    _ = try await APIClient.shared.activatePlan(id: pending.id)
                } catch {
                    // The server plan may have been lost; fall back to importing
                    // the local copy on the next sync.
                    self.planNeedsServerSync = true
                }
            }
            self.archiveCurrentPlan()
            self.plan = pending
            self.planNeedsServerSync = needsServerImport || self.planNeedsServerSync
            self.persist()
            self.rescheduleNotifications()
            self.syncPendingUserData()
            if openRecord {
                self.selectedTab = 1
            }
        }
    }

    func discardPendingPlan() {
        pendingPlanPreview = nil
        deferredPlanPreview = nil
        planNeedsServerSync = false
        persist()
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
