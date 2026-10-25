import Foundation
import Observation

@Observable
final class AppStore {
    var profile = UserProfile()
    var plan: TrainingPlan?
    var sessions: [WorkoutSession] = []
    var chat: [ChatMessage] = []
    var foodLogs: [FoodLog] = []
    var isGenerating = false
    var isReplying = false
    var toast: String?
    var reminderHour = 19
    var reminderMinute = 0
    var notificationsEnabled = false
    var useRemoteAI = AppConfig.useRemoteAI

    private let fileURL: URL = {
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("fitai-state.json")
    }()

    init() {
        load()
    }

    // MARK: - 派生状态

    var todayDay: PlanDay? {
        plan?.firstWeek.first { $0.weekday == Weekday.today }
    }

    var currentWeekSessions: [WorkoutSession] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return sessions
        }
        return sessions.filter { interval.contains($0.date) }
    }

    var weeklyCompletion: Double {
        guard profile.weeklyDays > 0 else { return 0 }
        return min(1.0, Double(currentWeekSessions.count) / Double(profile.weeklyDays))
    }

    var totalVolume: Double {
        sessions.reduce(0) { $0 + $1.volume }
    }

    var todayFoodLogs: [FoodLog] {
        foodLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayNutrition: NutritionTotals {
        todayFoodLogs.reduce(into: NutritionTotals()) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
        }
    }

    // MARK: - 建档与计划

    func completeOnboarding(_ draft: UserProfile) {
        profile = draft
        profile.isOnboarded = true
        persist()
        generatePlan()

        Task { @MainActor in
            let granted = await NotificationScheduler.shared.requestAuthorization()
            self.notificationsEnabled = granted
            self.persist()
            self.rescheduleNotifications()
        }
    }

    func generatePlan(force: Bool = true) {
        guard profile.isOnboarded else { return }
        if plan != nil && !force { return }

        isGenerating = true
        let snapshot = profile

        if useRemoteAI {
            Task { @MainActor in
                do {
                    try await APIClient.shared.syncProfile(snapshot)
                    try? await APIClient.shared.syncGoal(snapshot)
                    var generated = try await APIClient.shared.generatePlan(force: force)
                    generated.version = max(generated.version, (self.plan?.version ?? 0) + 1)
                    self.plan = generated
                    self.toast = "已由 AI 生成计划"
                } catch {
                    var fallback = PlanGenerator.generate(profile: snapshot)
                    fallback.version = (self.plan?.version ?? 0) + 1
                    self.plan = fallback
                    self.toast = "AI 服务不可用，已使用本地模板"
                }
                self.isGenerating = false
                self.persist()
                self.rescheduleNotifications()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            var generated = PlanGenerator.generate(profile: snapshot)
            generated.version = (self.plan?.version ?? 0) + 1
            self.plan = generated
            self.isGenerating = false
            self.persist()
            self.rescheduleNotifications()
        }
    }

    private func rescheduleNotifications() {
        guard notificationsEnabled else { return }
        Task { @MainActor in
            _ = await NotificationScheduler.shared.schedule(
                plan: self.plan,
                hour: self.reminderHour,
                minute: self.reminderMinute
            )
        }
    }

    func adjustPlan() {
        guard let current = plan else { return }
        let result = PlanGenerator.adjusted(
            plan: current,
            profile: profile,
            completionRate: weeklyCompletion
        )
        plan = result.plan
        toast = result.message
        persist()
    }

    func updateDay(_ day: PlanDay) {
        guard var current = plan,
              let index = current.days.firstIndex(where: { $0.id == day.id }) else {
            return
        }
        current.days[index] = day
        plan = current
        persist()
    }

    func addExercise(_ exercise: Exercise, to dayID: UUID) {
        guard var current = plan,
              let dayIndex = current.days.firstIndex(where: { $0.id == dayID }) else {
            return
        }
        let params = current.days[dayIndex].exercises.first
        let item = PlanExercise(
            slug: exercise.slug,
            sets: params?.sets ?? 3,
            reps: params?.reps ?? "10-12",
            weightKG: nil,
            restSec: params?.restSec ?? 60,
            rpe: 7
        )
        current.days[dayIndex].exercises.append(item)
        plan = current
        persist()
    }

    func removeExercise(_ exerciseID: UUID, from dayID: UUID) {
        guard var current = plan,
              let dayIndex = current.days.firstIndex(where: { $0.id == dayID }),
              current.days[dayIndex].exercises.count > 1 else {
            return
        }
        current.days[dayIndex].exercises.removeAll { $0.id == exerciseID }
        plan = current
        persist()
    }

    // MARK: - 训练与对话

    func record(day: PlanDay, sets: [SetLog], durationMinutes: Int, feeling: Int) {
        let session = WorkoutSession(
            dayTitle: day.title,
            durationMinutes: durationMinutes,
            feeling: feeling,
            sets: sets
        )
        sessions.insert(session, at: 0)
        persist()
    }

    func addFoodLog(_ log: FoodLog) {
        foodLogs.insert(log, at: 0)
        persist()
    }

    func removeFoodLog(_ id: UUID) {
        foodLogs.removeAll { $0.id == id }
        persist()
    }

    func sendChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chat.append(ChatMessage(role: .user, text: trimmed))

        if useRemoteAI {
            isReplying = true
            persist()
            Task { @MainActor in
                do {
                    let response = try await APIClient.shared.sendChat(message: trimmed)
                    self.chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: response.reply,
                            isSafety: response.safetyFlag != nil
                        )
                    )
                } catch {
                    self.chat.append(
                        CoachService.reply(to: trimmed, profile: self.profile, plan: self.plan)
                    )
                }
                self.isReplying = false
                self.persist()
            }
            return
        }

        chat.append(CoachService.reply(to: trimmed, profile: profile, plan: plan))
        persist()
    }

    func clearChat() {
        chat.removeAll()
        isReplying = false
        persist()
    }

    // MARK: - 档案与提醒

    func editProfile() {
        profile.isOnboarded = false
        persist()
    }

    func resetAll() {
        profile = UserProfile()
        plan = nil
        sessions = []
        chat = []
        foodLogs = []
        notificationsEnabled = false
        useRemoteAI = AppConfig.useRemoteAI
        reminderHour = 19
        reminderMinute = 0
        try? FileManager.default.removeItem(at: fileURL)
        NotificationScheduler.shared.cancelAll()
    }

    @discardableResult
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
        NotificationScheduler.shared.cancelAll()
        persist()
    }

    // MARK: - 持久化

    private struct PersistedState: Codable {
        var profile: UserProfile
        var plan: TrainingPlan?
        var sessions: [WorkoutSession]
        var chat: [ChatMessage]
        var foodLogs: [FoodLog]?
        var reminderHour: Int
        var reminderMinute: Int
        var notificationsEnabled: Bool
        var useRemoteAI: Bool?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }
        profile = state.profile
        plan = state.plan
        sessions = state.sessions
        chat = state.chat
        foodLogs = state.foodLogs ?? []
        reminderHour = state.reminderHour
        reminderMinute = state.reminderMinute
        notificationsEnabled = state.notificationsEnabled
        useRemoteAI = state.useRemoteAI ?? AppConfig.useRemoteAI
    }

    func persist() {
        let state = PersistedState(
            profile: profile,
            plan: plan,
            sessions: sessions,
            chat: chat,
            foodLogs: foodLogs,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            notificationsEnabled: notificationsEnabled,
            useRemoteAI: useRemoteAI
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
