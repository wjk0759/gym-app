import Foundation
import Observation

@Observable
final class AppStore {
    var profile = UserProfile()
    var plan: TrainingPlan?
    var planHistory: [TrainingPlan] = []
    var sessions: [WorkoutSession] = []
    var chat: [ChatMessage] = []
    var selectedTab = 0
    var planAdjustmentRequested = false
    var planAdjustmentStage = 0
    var planAdjustmentIssue = ""
    var planAdjustmentDetail = ""
    var planAdjustmentCategory = ""
    var planAdjustmentProposal: PlanAdjustmentProposal?
    var foodLogs: [FoodLog] = []
    var customFoods: [FoodItem] = []
    var dislikedSlugs: Set<String> = []
    var equipmentLibrary: [EquipmentItem] = []
    var bodyAnalyses: [BodyAnalysis] = []
    var bodyMetrics: [BodyMetric] = []
    var bodyCheckInFrequency: BodyCheckInFrequency = .off
    var bodyCheckInWeekday = 1
    var bodyCheckInDay = 1
    var bodyCheckInAnchor = Date()
    var bodyCheckInDismissedDate: String? = nil
    var useEquipmentLibraryForPlans = true
    var isGenerating = false
    var isReplying = false
    var isSyncingWorkouts = false
    var toast: String?
    var reminderHour = 19
    var reminderMinute = 0
    var notificationsEnabled = false
    var useRemoteAI = AppConfig.useRemoteAI
    /// StoreKit 权益通过 SubscriptionManager 同步；只有 Pro 才会请求远程 DeepSeek。
    var isPro = false
    /// 仅用于 Debug 预览 DeepSeek；正式包不会暴露出开关。
    var debugForceRemoteAI = false
    var healthKitEnabled = false

    private var currentUserID: String? = AuthTokenStore.shared.userID
    // 状态较大时 JSON 编码和原子落盘会阻塞主线程；写入串行放到 utility 队列。
    private let persistenceQueue = DispatchQueue(
        label: "com.fitai.appstore.persistence",
        qos: .utility
    )

    private var fileURL: URL {
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let filename = currentUserID.map { "fitai-state-\($0).json" } ?? "fitai-state.json"
        return directory.appendingPathComponent(filename)
    }

    init() {
        load()
        seedBodyMetricsIfNeeded()
    }

    // MARK: - 派生状态

    /// 当前计划周。按计划所在自然周（周一开始）计算，并限制在计划周数内。
    var currentPlanWeek: Int {
        guard let plan else { return 1 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return 1
        }
        let now = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: planMonday, to: now).day ?? 0
        return min(max(1, days / 7 + 1), max(1, plan.weeks))
    }

    var currentPlanWeekInterval: DateInterval? {
        guard let plan else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start),
              let weekStart = calendar.date(
                byAdding: .day,
                value: (currentPlanWeek - 1) * 7,
                to: planMonday
              ),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return nil
        }
        return DateInterval(start: weekStart, end: weekEnd)
    }

    var isPlanFinished: Bool {
        guard let plan else { return false }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return false
        }
        let days = calendar.dateComponents(
            [.day],
            from: planMonday,
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        return days >= plan.weeks * 7
    }

    var todayDay: PlanDay? {
        guard let plan else { return nil }
        if let scheduled = plan.day(on: Date()) {
            return scheduled
        }
        if plan.days.contains(where: { $0.date != nil }) {
            return nil
        }
        return plan.weekDays(in: currentPlanWeek).first { $0.weekday == Weekday.today }
    }

    var currentWeekSessions: [WorkoutSession] {
        if let interval = currentPlanWeekInterval {
            return sessions.filter { interval.contains($0.date) }
        }
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
            total.fiber += log.fiber ?? 0
        }
    }

    var recentAverageRPE: Double {
        let recentSets = sessions.prefix(3).flatMap { $0.sets }.filter { $0.completed }
        guard !recentSets.isEmpty else { return 0 }
        return recentSets.reduce(0.0) { $0 + $1.rpe } / Double(recentSets.count)
    }

    /// 本周 RPE，和“本周完成率”使用同一个时间窗口，复盘时更一致。
    var currentWeekAverageRPE: Double {
        let sets = currentWeekSessions.prefix(3).flatMap { $0.sets }.filter { $0.completed }
        guard !sets.isEmpty else { return 0 }
        return sets.reduce(0.0) { $0 + $1.rpe } / Double(sets.count)
    }

    var currentWeekVolume: Double {
        currentWeekSessions.reduce(0) { $0 + $1.volume }
    }

    var canUseRemoteAI: Bool {
        useRemoteAI && (isPro || debugForceRemoteAI)
    }

    var planAdjustmentPreview: PlanGenerator.Adjustment {
        PlanGenerator.adjustment(
            completionRate: weeklyCompletion,
            averageRPE: currentWeekAverageRPE
        )
    }

    var equipmentSlugsForPlan: [String] {
        guard useEquipmentLibraryForPlans else { return [] }
        return equipmentLibrary.compactMap(\.slug).filter { slug in
            guard let exercise = ExerciseLibrary.exercise(slug: slug) else { return false }
            return profile.equipment.contains(exercise.equipment)
        }
    }

    // MARK: - 建档与计划

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
        generatePlan()

        Task { @MainActor in
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
        if planSettingsChanged, hasPlanEquipment {
            generatePlan(force: true)
        } else {
            rescheduleNotifications()
        }
    }

    func generatePlan(force: Bool = true, weeklyWeekdays: [Int]? = nil) {
        guard profile.isOnboarded else { return }
        guard hasPlanEquipment else {
            toast = "请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索"
            return
        }
        if plan != nil && !force { return }

        isGenerating = true
        let snapshot = profile
        let librarySlugs = equipmentSlugsForPlan

        if canUseRemoteAI && weeklyWeekdays == nil {
            Task { @MainActor in
                do {
                    async let profileSync = APIClient.shared.syncProfile(snapshot)
                    async let goalSync = APIClient.shared.syncGoal(snapshot)
                    try await profileSync
                    _ = try? await goalSync
                    var generated = try await APIClient.shared.generatePlan(
                        force: force,
                        equipmentSlugs: librarySlugs,
                        split: snapshot.split
                    )
                    generated.version = max(generated.version, (self.plan?.version ?? 0) + 1)
                    self.archiveCurrentPlan()
                    self.plan = generated
                    self.toast = "已由 AI 生成计划"
                } catch {
                    var fallback = PlanGenerator.generate(
                        profile: snapshot,
                        dislikedSlugs: self.dislikedSlugs,
                        equipmentSlugs: librarySlugs,
                        weeklyWeekdays: weeklyWeekdays
                    )
                    fallback.version = (self.plan?.version ?? 0) + 1
                    self.archiveCurrentPlan()
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
            var generated = PlanGenerator.generate(
                profile: snapshot,
                dislikedSlugs: self.dislikedSlugs,
                equipmentSlugs: librarySlugs,
                weeklyWeekdays: weeklyWeekdays
            )
            generated.version = (self.plan?.version ?? 0) + 1
            self.archiveCurrentPlan()
            self.plan = generated
            self.isGenerating = false
            self.persist()
            self.rescheduleNotifications()
        }
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

    func adjustPlan() {
        guard let current = plan else { return }
        let result = PlanGenerator.adjusted(
            plan: current,
            profile: profile,
            completionRate: weeklyCompletion,
            averageRPE: currentWeekAverageRPE
        )
        archiveCurrentPlan()
        plan = result.plan
        toast = result.message
        persist()
        rescheduleNotifications()
    }

    func restorePlan(_ archived: TrainingPlan) {
        guard archived.id != plan?.id else { return }
        archiveCurrentPlan()
        planHistory.removeAll { $0.id == archived.id }
        plan = archived
        toast = "已恢复计划 v\(archived.version)"
        persist()
        rescheduleNotifications()
    }

    private func archiveCurrentPlan() {
        guard let current = plan else { return }
        guard planHistory.first?.id != current.id else { return }
        planHistory.insert(current, at: 0)
        if planHistory.count > 5 {
            planHistory.removeLast(planHistory.count - 5)
        }
    }

    func lastSet(for slug: String) -> SetLog? {
        for session in sessions {
            if let set = session.sets.last(where: { $0.slug == slug && $0.completed }) {
                return set
            }
        }
        return nil
    }

    /// 历史最佳组：先比较重量，再比较次数；自重动作按次数比较。
    func bestSet(for slug: String) -> SetLog? {
        sessions
            .flatMap(\.sets)
            .filter { $0.slug == slug && $0.completed }
            .max { left, right in
                if left.weightKG != right.weightKG {
                    return left.weightKG < right.weightKG
                }
                return left.reps < right.reps
            }
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
        dislikedSlugs.remove(exercise.slug)
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
        if let removed = current.days[dayIndex].exercises.first(where: { $0.id == exerciseID }) {
            dislikedSlugs.insert(removed.slug)
        }
        current.days[dayIndex].exercises.removeAll { $0.id == exerciseID }
        plan = current
        persist()
    }

    func clearPreferences() {
        dislikedSlugs.removeAll()
        persist()
    }

    // MARK: - 器械库与体型分析

    func addEquipment(_ item: EquipmentItem) {
        equipmentLibrary.insert(item, at: 0)
        persist()
    }

    /// 批量把动作加入器械库，自动跳过已存在的动作，返回真正新增的数量。
    @discardableResult
    func addExercisesToEquipmentLibrary(
        _ exercises: [Exercise],
        note: String = "从已选动作加入"
    ) -> Int {
        var existingSlugs = Set(equipmentLibrary.compactMap(\.slug))
        let items = exercises.compactMap { exercise -> EquipmentItem? in
            guard !existingSlugs.contains(exercise.slug) else { return nil }
            existingSlugs.insert(exercise.slug)
            return EquipmentItem(
                name: exercise.nameZH,
                slug: exercise.slug,
                muscle: exercise.muscle,
                equipment: exercise.equipment,
                videoURL: exercise.videoURL?.absoluteString,
                notes: note
            )
        }
        guard !items.isEmpty else { return 0 }
        equipmentLibrary.insert(contentsOf: items, at: 0)
        persist()
        return items.count
    }

    func removeEquipment(_ id: UUID) {
        equipmentLibrary.removeAll { $0.id == id }
        persist()
    }

    func addBodyAnalysis(_ analysis: BodyAnalysis) {
        bodyAnalyses.insert(analysis, at: 0)
        persist()
    }

    func applyBodyAnalysis(_ analysis: BodyAnalysis) {
        guard var current = plan else {
            toast = "先生成训练计划，再应用体型分析"
            return
        }

        current.version += 1
        current.updatedAt = Date()
        current.days = current.days.map { day in
            var newDay = day
            newDay.id = UUID()
            newDay.exercises = day.exercises.map { item in
                var newItem = item
                newItem.id = UUID()
                if let muscle = item.exercise?.muscle,
                   analysis.focusAreas.contains(muscle) {
                    newItem.sets = min(6, item.sets + 1)
                }
                return newItem
            }
            return newDay
        }
        archiveCurrentPlan()
        plan = current

        if let index = bodyAnalyses.firstIndex(where: { $0.id == analysis.id }) {
            bodyAnalyses[index].appliedToPlan = true
        } else {
            var copy = analysis
            copy.appliedToPlan = true
            bodyAnalyses.insert(copy, at: 0)
        }

        toast = "已应用体型分析：重点部位每周增加 1 组"
        persist()
    }

    // MARK: - 训练与对话

    func record(
        day: PlanDay,
        sets: [SetLog],
        durationMinutes: Int,
        feeling: Int,
        notes: String? = nil
    ) {
        let cleanNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = WorkoutSession(
            dayTitle: day.title,
            durationMinutes: durationMinutes,
            feeling: feeling,
            notes: (cleanNotes?.isEmpty ?? true) ? nil : cleanNotes,
            sets: sets
        )
        sessions.insert(session, at: 0)
        persist()
        syncPendingWorkouts()

        if healthKitEnabled {
            let end = Date()
            let start = end.addingTimeInterval(-Double(durationMinutes * 60))
            Task {
                try? await HealthKitService.shared.saveStrengthWorkout(
                    start: start,
                    end: end
                )
            }
        }
    }

    func addSession(_ session: WorkoutSession) {
        sessions.insert(session, at: 0)
        persist()
        syncPendingWorkouts()
    }

    func updateSession(_ session: WorkoutSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else {
            return
        }
        sessions[index] = session
        persist()
    }

    /// 将本地训练记录补传到 FastAPI；失败时保持 pending，下次登录或完成训练再试。
    func syncPendingWorkouts() {
        guard !isSyncingWorkouts,
              AuthTokenStore.shared.accessToken != nil else { return }
        let pending = sessions.filter { $0.syncedAt == nil }
        guard !pending.isEmpty else { return }
        isSyncingWorkouts = true
        Task { @MainActor in
            defer { self.isSyncingWorkouts = false }
            for session in pending {
                do {
                    let remoteID = try await APIClient.shared.createWorkout(session)
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        self.sessions[index].remoteID = remoteID
                        self.sessions[index].syncedAt = Date()
                    }
                } catch {
                    // 网络或服务端暂时不可用时保留待同步状态，不阻塞本地训练闭环。
                }
            }
            self.persist()
        }
    }

    func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    func addFoodLog(_ log: FoodLog) {
        foodLogs.insert(log, at: 0)
        persist()
    }

    func addFoodLogs(_ logs: [FoodLog]) {
        guard !logs.isEmpty else { return }
        foodLogs.insert(contentsOf: logs, at: 0)
        persist()
    }

    func addCustomFood(_ food: FoodItem) {
        customFoods.removeAll { $0.name == food.name }
        customFoods.insert(food, at: 0)
        persist()
    }

    func removeFoodLog(_ id: UUID) {
        foodLogs.removeAll { $0.id == id }
        persist()
    }

    func sendChat(_ text: String, skill: CoachSkill = .trainer) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        chat.append(ChatMessage(role: .user, text: trimmed))

        if canUseRemoteAI {
            isReplying = true
            persist()
            Task { @MainActor in
                do {
                    let response = try await APIClient.shared.sendChat(
                        message: trimmed,
                        skill: skill
                    )
                    self.chat.append(
                        ChatMessage(
                            role: .assistant,
                            text: response.reply,
                            isSafety: response.safetyFlag != nil
                        )
                    )
                } catch {
                    self.chat.append(
                        CoachService.reply(
                            to: trimmed,
                            profile: self.profile,
                            plan: self.plan,
                            skill: skill,
                            period: self.todayPeriod
                        )
                    )
                }
                self.isReplying = false
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
        chat.removeAll()
        planAdjustmentStage = 0
        planAdjustmentProposal = nil
        planAdjustmentRequested = false
        isReplying = false
        persist()
    }

    // MARK: - 档案与提醒

    func resetAll() {
        flushPersistence()
        try? FileManager.default.removeItem(at: fileURL)
        resetInMemory()
        NotificationScheduler.shared.cancelAll()
    }

    /// 登录账号切换时使用独立本地数据文件，避免 A 账号看到 B 账号数据。
    func switchUser(_ userID: String?) {
        guard userID != currentUserID else { return }
        persist()
        flushPersistence()
        currentUserID = userID
        resetInMemory()
        load()
        seedBodyMetricsIfNeeded()
    }

    private func resetInMemory() {
        profile = UserProfile()
        plan = nil
        planHistory = []
        sessions = []
        chat = []
        foodLogs = []
        customFoods = []
        dislikedSlugs = []
        notificationsEnabled = false
        useRemoteAI = AppConfig.useRemoteAI
        healthKitEnabled = false
        equipmentLibrary = []
        bodyAnalyses = []
        bodyMetrics = []
        bodyCheckInFrequency = .off
        bodyCheckInWeekday = 1
        bodyCheckInDay = 1
        bodyCheckInAnchor = Date()
        bodyCheckInDismissedDate = nil
        useEquipmentLibraryForPlans = true
        reminderHour = 19
        reminderMinute = 0
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

    // MARK: - 持久化

    private struct PersistedState: Codable {
        var profile: UserProfile
        var plan: TrainingPlan?
        var planHistory: [TrainingPlan]?
        var sessions: [WorkoutSession]
        var chat: [ChatMessage]
        var foodLogs: [FoodLog]?
        var customFoods: [FoodItem]?
        var dislikedSlugs: [String]?
        var reminderHour: Int
        var reminderMinute: Int
        var notificationsEnabled: Bool
        var useRemoteAI: Bool?
        var healthKitEnabled: Bool?
        var equipmentLibrary: [EquipmentItem]?
        var bodyAnalyses: [BodyAnalysis]?
        var useEquipmentLibraryForPlans: Bool?
        var bodyMetrics: [BodyMetric]?
        var bodyCheckInFrequency: BodyCheckInFrequency?
        var bodyCheckInWeekday: Int?
        var bodyCheckInDay: Int?
        var bodyCheckInAnchor: Date?
        var bodyCheckInDismissedDate: String?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            resetInMemory()
            return
        }
        profile = state.profile
        plan = state.plan
        planHistory = state.planHistory ?? []
        sessions = state.sessions
        chat = state.chat
        foodLogs = state.foodLogs ?? []
        customFoods = state.customFoods ?? []
        dislikedSlugs = Set(state.dislikedSlugs ?? [])
        reminderHour = state.reminderHour
        reminderMinute = state.reminderMinute
        notificationsEnabled = state.notificationsEnabled
        useRemoteAI = state.useRemoteAI ?? AppConfig.useRemoteAI
        healthKitEnabled = state.healthKitEnabled ?? false
        equipmentLibrary = state.equipmentLibrary ?? []
        bodyAnalyses = state.bodyAnalyses ?? []
        bodyMetrics = state.bodyMetrics ?? []
        bodyCheckInFrequency = state.bodyCheckInFrequency ?? .off
        bodyCheckInWeekday = state.bodyCheckInWeekday ?? 1
        bodyCheckInDay = state.bodyCheckInDay ?? 1
        bodyCheckInAnchor = state.bodyCheckInAnchor ?? Date()
        bodyCheckInDismissedDate = state.bodyCheckInDismissedDate
        useEquipmentLibraryForPlans = state.useEquipmentLibraryForPlans ?? true
    }

    func persist() {
        let state = PersistedState(
            profile: profile,
            plan: plan,
            planHistory: planHistory,
            sessions: sessions,
            chat: chat,
            foodLogs: foodLogs,
            customFoods: customFoods,
            dislikedSlugs: Array(dislikedSlugs).sorted(),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            notificationsEnabled: notificationsEnabled,
            useRemoteAI: useRemoteAI,
            healthKitEnabled: healthKitEnabled,
            equipmentLibrary: equipmentLibrary,
            bodyAnalyses: bodyAnalyses,
            useEquipmentLibraryForPlans: useEquipmentLibraryForPlans,
            bodyMetrics: bodyMetrics,
            bodyCheckInFrequency: bodyCheckInFrequency,
            bodyCheckInWeekday: bodyCheckInWeekday,
            bodyCheckInDay: bodyCheckInDay,
            bodyCheckInAnchor: bodyCheckInAnchor,
            bodyCheckInDismissedDate: bodyCheckInDismissedDate
        )
        let url = fileURL
        persistenceQueue.async {
            guard let data = try? JSONEncoder().encode(state) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// 进入后台或切换账号前调用，确保已排队的写入完成。
    func flushPersistence() {
        persistenceQueue.sync {}
    }

    func exportData() -> String {
        let payload = ExportPayload(
            exportedAt: Date(),
            profile: profile,
            plan: plan,
            planHistory: planHistory,
            sessions: sessions,
            chat: chat,
            foodLogs: foodLogs,
            customFoods: customFoods,
            dislikedSlugs: Array(dislikedSlugs).sorted(),
            healthKitEnabled: healthKitEnabled,
            bodyAnalyses: bodyAnalyses,
            equipmentLibrary: equipmentLibrary,
            bodyMetrics: bodyMetrics,
            bodyCheckInFrequency: bodyCheckInFrequency
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private struct ExportPayload: Codable {
        let exportedAt: Date
        let profile: UserProfile
        let plan: TrainingPlan?
        let planHistory: [TrainingPlan]
        let sessions: [WorkoutSession]
        let chat: [ChatMessage]
        let foodLogs: [FoodLog]
        let customFoods: [FoodItem]
        let dislikedSlugs: [String]
        let healthKitEnabled: Bool
        let bodyAnalyses: [BodyAnalysis]
        let equipmentLibrary: [EquipmentItem]
        let bodyMetrics: [BodyMetric]
        let bodyCheckInFrequency: BodyCheckInFrequency
    }
}
