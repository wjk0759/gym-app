import Foundation

extension AppStore {
    func enableReminders(hour: Int, minute: Int) async -> Int {
        reminderHour = hour
        reminderMinute = minute
        remindersEnabled = true
        let granted = await NotificationScheduler.shared.requestAuthorization()
        guard granted else {
            notificationsEnabled = false
            persist()
            markPreferencesDirty()
            return 0
        }
        let count = await NotificationScheduler.shared.schedule(
            plan: plan,
            hour: hour,
            minute: minute
        )
        notificationsEnabled = granted
        persist()
        markPreferencesDirty()
        return count
    }

    func disableReminders() {
        remindersEnabled = false
        notificationsEnabled = false
        NotificationScheduler.shared.cancelWorkoutReminders()
        persist()
        markPreferencesDirty()
    }

    /// Habit reminders are local-only: the server parses the intent and shows a
    /// confirmation card, but each device must schedule its own notification.
    @MainActor
    func enableHabitReminder(kind: String, hour: Int, minute: Int) async -> Bool {
        let granted = await NotificationScheduler.shared.requestAuthorization()
        notificationsEnabled = granted
        guard granted else {
            persist()
            return false
        }
        let scheduled = await NotificationScheduler.shared.scheduleHabitReminder(
            kind: kind,
            hour: hour,
            minute: minute
        )
        persist()
        return scheduled
    }

    func disableHabitReminder(kind: String) {
        NotificationScheduler.shared.cancelHabitReminder(kind: kind)
        persist()
    }

    /// Account-level opt-out for in-app proactive coach nudges. This does not
    /// touch local notification permission or the daily cron.
    func setProactiveCoachEnabled(_ enabled: Bool) {
        proactiveCoachEnabled = enabled
        persist()
        markPreferencesDirty()
    }

    /// Reconcile the account-level reminder intent with this device's
    /// notification permission and current plan. Called after cloud sync and
    /// when opening settings, so a device that never granted permission cannot
    /// show "on" just because another device enabled reminders.
    @MainActor
    func refreshNotificationDeviceState() async {
        let authorized = await NotificationScheduler.shared.isAuthorized()
        if remindersEnabled, authorized {
            _ = await NotificationScheduler.shared.schedule(
                plan: plan,
                hour: reminderHour,
                minute: reminderMinute
            )
            if !notificationsEnabled {
                notificationsEnabled = true
                persist()
            }
            return
        }
        NotificationScheduler.shared.cancelWorkoutReminders()
        if notificationsEnabled {
            notificationsEnabled = false
            persist()
        }
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
                var metric = bodyMetrics.first(where: {
                    $0.dateKey == FitnessDate.key(Date())
                }) ?? BodyMetric(
                    date: Date(),
                    weightKG: nil,
                    bodyFatPCT: nil,
                    waistCM: nil
                )
                metric.weightKG = weight
                appendBodyMetric(metric)
            }
            persist()
            syncPendingUserData()
            dataDidChange(.bodyMetric)
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
