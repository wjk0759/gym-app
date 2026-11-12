import Foundation

extension AppStore {
    func enableReminders(hour: Int, minute: Int) async -> Int {
        reminderHour = hour
        reminderMinute = minute
        let granted = await NotificationScheduler.shared.requestAuthorization()
        guard granted else {
            notificationsEnabled = false
            persist()
            return 0
        }
        let count = await NotificationScheduler.shared.schedule(
            plan: plan,
            hour: hour,
            minute: minute
        )
        notificationsEnabled = granted
        persist()
        return count
    }

    func disableReminders() {
        notificationsEnabled = false
        NotificationScheduler.shared.cancelWorkoutReminders()
        persist()
    }

    // MARK: - 休息提醒

    func setRestLiveActivityEnabled(_ enabled: Bool) {
        restLiveActivityEnabled = enabled
        persist()

        if enabled {
            let dayTitle = workoutDraft.flatMap { draft in
                plan?.days.first(where: { $0.id == draft.dayID })?.title
            } ?? "训练"
            Task { @MainActor in
                await RestLiveActivityManager.shared.resumeFromDraftIfNeeded(
                    draft: workoutDraft,
                    dayTitle: dayTitle
                )
            }
        } else {
            Task { @MainActor in
                await RestLiveActivityManager.shared.endAll()
            }
        }
    }

    func enableRestNotifications() async -> Bool {
        let granted = await NotificationScheduler.shared.requestAuthorization()
        restNotificationsEnabled = granted
        persist()
        return granted
    }

    func disableRestNotifications() {
        restNotificationsEnabled = false
        NotificationScheduler.shared.cancelRestNotifications()
        persist()
    }

    // MARK: - Apple 健康

    @discardableResult
    func enableHealthKit() async -> Bool {
        guard HealthKitService.shared.isAvailable else { return false }
        do {
            let granted = try await HealthKitService.shared.requestAuthorization()
            healthKitEnabled = granted
            if granted, let weight = try? await HealthKitService.shared.latestBodyMassKG() {
                profile.weightKG = weight
            }
            persist()
            return granted
        } catch {
            healthKitEnabled = false
            persist()
            return false
        }
    }

    func disableHealthKit() {
        healthKitEnabled = false
        persist()
    }

}
