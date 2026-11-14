import Foundation

extension AppStore {
    func completeOnboarding(_ draft: UserProfile) {
        var value = draft
        value.isOnboarded = true
        let goal = value.goalType.rawValue
        let weeklyDays = String(value.weeklyDays)
        Task { @MainActor in
            Telemetry.shared.track(
                "onboarding_completed",
                properties: [
                    "goal": goal,
                    "weekly_days": weeklyDays,
                ]
            )
        }
        normalizeGoalStart(&value)
        profile = value
        appendBodyMetric(
            BodyMetric(
                date: Date(),
                weightKG: value.weightKG,
                bodyFatPCT: value.bodyFatPCT,
                waistCM: value.waistCM,
                armCM: value.armCM,
                thighCM: value.thighCM
            )
        )
        persist()
        syncPendingUserData()
        generatePlan(onboarding: true)

        Task { @MainActor in
            // The onboarding plan may be generated locally. Ensure the
            // profile exists server-side before recording its one-time trial.
            try? await APIClient.shared.syncProfile(value)
            try? await APIClient.shared.syncGoal(value)
            self.syncPendingUserData()
            let granted = await NotificationScheduler.shared.requestAuthorization()
            self.notificationsEnabled = granted
            self.persist()
            self.rescheduleNotifications()
        }
    }

    func updateProfile(_ updated: UserProfile, regeneratePlan: Bool = false) {
        let old = profile
        var value = updated
        value.isOnboarded = true
        let goalChanged = old.goalType != value.goalType
            || old.targetWeightKG != value.targetWeightKG
            || old.targetWaistCM != value.targetWaistCM
            || old.targetBodyFatPCT != value.targetBodyFatPCT
        if goalChanged {
            value.goalStartWeight = value.weightKG
            value.goalStartDate = Date()
        }
        normalizeGoalStart(&value)
        let planSettingsChanged = old.goalType != value.goalType
            || old.split != value.split
            || old.weeklyDays != value.weeklyDays
            || old.sessionMinutes != value.sessionMinutes
            || old.experience != value.experience
            || old.equipment != value.equipment
        profile = value
        let weightChanged = old.weightKG != value.weightKG
        let bodyFatChanged = old.bodyFatPCT != value.bodyFatPCT
        let waistChanged = old.waistCM != value.waistCM
        let armChanged = old.armCM != value.armCM
        let thighChanged = old.thighCM != value.thighCM
        if weightChanged || bodyFatChanged || waistChanged || armChanged || thighChanged {
            appendBodyMetric(
                BodyMetric(
                    date: Date(),
                    weightKG: weightChanged ? value.weightKG : nil,
                    bodyFatPCT: bodyFatChanged ? value.bodyFatPCT : nil,
                    waistCM: waistChanged ? value.waistCM : nil,
                    armCM: armChanged ? value.armCM : nil,
                    thighCM: thighChanged ? value.thighCM : nil
                )
            )
        }
        persist()
        syncPendingUserData()
        if planSettingsChanged, hasPlanEquipment, regeneratePlan {
            generatePlan(force: true)
        } else {
            if planSettingsChanged {
                toast = "档案已更新；训练设置有变化，需要重排计划时请在训练手账重新生成"
            }
            rescheduleNotifications()
        }
    }
}
