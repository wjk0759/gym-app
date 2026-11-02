import Foundation

extension AppStore {
    func completeOnboarding(_ draft: UserProfile) {
        var value = draft
        value.isOnboarded = true
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
            let granted = await NotificationScheduler.shared.requestAuthorization()
            self.notificationsEnabled = granted
            self.persist()
            self.rescheduleNotifications()
        }
    }

    func updateProfile(_ updated: UserProfile) {
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
        if planSettingsChanged, hasPlanEquipment {
            generatePlan(force: true)
        } else {
            rescheduleNotifications()
        }
    }
}
