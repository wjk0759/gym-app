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
    var isSyncingRemoteWorkouts = false
    var isSyncingUserData = false
    /// 已从本地删除、但服务端 DELETE 尚未成功的训练记录 ID。
    var pendingWorkoutDeletionIDs: [String] = []
    var isAgentWorking = false
    var agentSessionID: UUID?
    var agentProposal: AgentPlanProposal?
    var weeklyReview: AgentWeeklyReview?
    var isReviewingWeekly = false
    private var reviewRefreshQueued = false
    private var reviewNotifyQueued = false
    var toast: String?
    var reminderHour = 19
    var reminderMinute = 0
    var notificationsEnabled = false
    var useRemoteAI = AppConfig.useRemoteAI
    /// StoreKit 权益通过 SubscriptionManager 同步；只有 Pro 才会请求远程 DeepSeek。
    var isPro = false
    /// 仅用于 Debug 预览 DeepSeek；正式包不会暴露出开关。
    var debugForceRemoteAI = AppConfig.debugForceRemoteAI
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
        syncPendingUserData()
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
        syncPendingUserData()
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
        syncPendingUserData()
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
        syncPendingUserData()
        return items.count
    }

    func removeEquipment(_ id: UUID) {
        equipmentLibrary.removeAll { $0.id == id }
        persist()
        Task {
            try? await APIClient.shared.deleteEquipmentItem(id: id)
        }
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
            sets: sets,
            programDayID: day.id.uuidString
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
        var updated = session
        if updated.remoteID != nil {
            updated.pendingRemoteUpdate = true
        }
        sessions[index] = updated
        persist()
        syncPendingWorkouts()
    }

    /// 将本地训练记录补传到 FastAPI；失败时保持 pending，下次登录或完成训练再试。
    /// 创建、修改、删除共用一个串行通道，避免离线恢复时互相覆盖。
    func syncPendingWorkouts() {
        guard !isSyncingWorkouts,
              AuthTokenStore.shared.accessToken != nil else { return }
        let pendingCreates = sessions.filter { $0.syncedAt == nil }
        let pendingUpdates = sessions.filter {
            $0.remoteID != nil && $0.syncedAt != nil && $0.pendingRemoteUpdate == true
        }
        let pendingDeletes = pendingWorkoutDeletionIDs
        guard !pendingCreates.isEmpty || !pendingUpdates.isEmpty || !pendingDeletes.isEmpty else {
            return
        }
        let accountID = currentUserID
        isSyncingWorkouts = true
        Task { @MainActor in
            defer { self.isSyncingWorkouts = false }
            var createdAny = false
            var changedAny = false

            for remoteID in pendingDeletes {
                do {
                    try await APIClient.shared.deleteWorkout(id: remoteID)
                    guard self.currentUserID == accountID else { return }
                    self.pendingWorkoutDeletionIDs.removeAll { $0 == remoteID }
                    self.persist()
                    changedAny = true
                } catch let error as APIError where error.statusCode == 404 {
                    // 服务端已经不存在该记录，删除墓碑视为完成。
                    guard self.currentUserID == accountID else { return }
                    self.pendingWorkoutDeletionIDs.removeAll { $0 == remoteID }
                    self.persist()
                    changedAny = true
                } catch {
                    // 保留墓碑，下一次前台刷新继续删除，避免离线删除被服务端数据复活。
                }
            }

            for session in pendingCreates {
                do {
                    let remoteID = try await APIClient.shared.createWorkout(session)
                    guard self.currentUserID == accountID else { return }
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        self.sessions[index].remoteID = remoteID
                        self.sessions[index].syncedAt = Date()
                        self.sessions[index].pendingRemoteUpdate = nil
                    }
                    createdAny = true
                    changedAny = true
                } catch {
                    // 网络或服务端暂时不可用时保留待同步状态，不阻塞本地训练闭环。
                }
            }

            for session in pendingUpdates {
                guard let remoteID = session.remoteID else { continue }
                do {
                    try await APIClient.shared.updateWorkout(id: remoteID, session: session)
                    guard self.currentUserID == accountID else { return }
                    if let index = self.sessions.firstIndex(where: { $0.id == session.id }) {
                        var latest = self.sessions[index]
                        var sent = session
                        latest.pendingRemoteUpdate = nil
                        sent.pendingRemoteUpdate = nil
                        if latest == sent {
                            self.sessions[index].pendingRemoteUpdate = nil
                        }
                    }
                    changedAny = true
                } catch {
                    // 保留 pendingRemoteUpdate，下一次前台刷新重试 PATCH。
                }
            }
            self.persist()
            if changedAny {
                self.refreshWeeklyReview(force: true, notifyWhenReady: createdAny)
            }
        }
    }

    func deleteSession(_ id: UUID) {
        guard let remoteID = sessions.first(where: { $0.id == id })?.remoteID else {
            sessions.removeAll { $0.id == id }
            persist()
            return
        }
        sessions.removeAll { $0.id == id }
        if !pendingWorkoutDeletionIDs.contains(remoteID) {
            pendingWorkoutDeletionIDs.append(remoteID)
        }
        persist()
        syncPendingWorkouts()
    }

    /// 拉取服务端近 90 天训练历史，按 remoteID 合并；本地未上传的修改优先。
    func syncRemoteWorkouts() {
        guard !isSyncingRemoteWorkouts,
              AuthTokenStore.shared.accessToken != nil else { return }
        let accountID = currentUserID
        isSyncingRemoteWorkouts = true
        Task { @MainActor in
            defer { self.isSyncingRemoteWorkouts = false }
            do {
                let remote = try await APIClient.shared.fetchRecentWorkouts()
                guard self.currentUserID == accountID else { return }
                self.mergeRemoteWorkouts(remote)
            } catch {
                // 离线或服务端暂不可用时保留本地历史，下一次前台刷新再试。
            }
        }
    }

    private func mergeRemoteWorkouts(_ remote: [RemoteWorkout]) {
        let deleting = Set(pendingWorkoutDeletionIDs)
        var changed = false
        for item in remote where !deleting.contains(item.id) {
            let planTitle = item.programDayID.flatMap { dayID in
                plan?.days.first(where: { $0.id.uuidString == dayID })?.title
            }
            if let index = sessions.firstIndex(where: { $0.remoteID == item.id }) {
                guard sessions[index].pendingRemoteUpdate != true else { continue }
                let localID = sessions[index].id
                let localTitle = sessions[index].dayTitle
                let merged = makeWorkoutSession(
                    from: item,
                    dayTitle: planTitle ?? localTitle,
                    localID: localID
                )
                if merged != sessions[index] {
                    sessions[index] = merged
                    changed = true
                }
            } else {
                sessions.append(
                    makeWorkoutSession(
                        from: item,
                        dayTitle: planTitle ?? "训练记录"
                    )
                )
                changed = true
            }
        }
        if changed {
            sessions.sort { $0.date > $1.date }
            persist()
        }
    }

    private func makeWorkoutSession(
        from item: RemoteWorkout,
        dayTitle: String,
        localID: UUID = UUID()
    ) -> WorkoutSession {
        let finishedAt = item.finishedAt ?? item.startedAt
        let duration = item.durationMin ?? max(
            0,
            Int(finishedAt.timeIntervalSince(item.startedAt) / 60)
        )
        return WorkoutSession(
            id: localID,
            date: finishedAt,
            dayTitle: dayTitle,
            durationMinutes: duration,
            feeling: min(5, max(1, item.feeling ?? 3)),
            notes: item.notes,
            sets: item.sets.map { set in
                SetLog(
                    slug: set.slug,
                    setIndex: set.setIndex,
                    weightKG: set.weightKG ?? 0,
                    reps: set.reps ?? 0,
                    rpe: set.rpe ?? 7,
                    completed: set.completed
                )
            },
            programDayID: item.programDayID,
            remoteID: item.id,
            syncedAt: Date()
        )
    }

    func addFoodLog(_ log: FoodLog) {
        foodLogs.insert(log, at: 0)
        persist()
        syncPendingUserData()
    }

    func addFoodLogs(_ logs: [FoodLog]) {
        guard !logs.isEmpty else { return }
        foodLogs.insert(contentsOf: logs, at: 0)
        persist()
        syncPendingUserData()
    }

    func addCustomFood(_ food: FoodItem) {
        customFoods.removeAll { $0.name == food.name }
        customFoods.insert(food, at: 0)
        persist()
    }

    func removeFoodLog(_ id: UUID) {
        foodLogs.removeAll { $0.id == id }
        persist()
        Task {
            try? await APIClient.shared.deleteFoodLog(id: id)
        }
    }

    // MARK: - Cross-device data sync

    func syncPendingUserData() {
        guard !isSyncingUserData,
              AuthTokenStore.shared.accessToken != nil else { return }
        isSyncingUserData = true
        Task { @MainActor in
            defer {
                self.isSyncingUserData = false
                self.persist()
            }
            await self.pushPendingFoodLogs()
            await self.pushPendingBodyMetrics()
            await self.pushPendingEquipment()
            await self.pullCloudUserData()
        }
    }

    private func pushPendingFoodLogs() async {
        for log in foodLogs where log.syncedAt == nil {
            do {
                try await APIClient.shared.syncFoodLog(log)
                if let index = foodLogs.firstIndex(where: { $0.id == log.id }) {
                    foodLogs[index].syncedAt = Date()
                }
            } catch {
                // Keep pending for the next foreground/login retry.
            }
        }
        foodLogs.sort { $0.date > $1.date }
    }

    private func pushPendingBodyMetrics() async {
        for metric in bodyMetrics where metric.syncedAt == nil {
            do {
                try await APIClient.shared.syncBodyMetric(metric)
                if let index = bodyMetrics.firstIndex(where: { $0.id == metric.id }) {
                    bodyMetrics[index].syncedAt = Date()
                }
            } catch {
                // Keep pending.
            }
        }
        bodyMetrics.sort { $0.date > $1.date }
    }

    private func pushPendingEquipment() async {
        for item in equipmentLibrary where item.syncedAt == nil {
            do {
                try await APIClient.shared.syncEquipmentItem(item)
                if let index = equipmentLibrary.firstIndex(where: { $0.id == item.id }) {
                    equipmentLibrary[index].syncedAt = Date()
                }
            } catch {
                // Keep pending.
            }
        }
    }

    private func pullCloudUserData() async {
        if let remote = try? await APIClient.shared.fetchFoodLogs() {
            let localIDs = Set(foodLogs.map(\.id))
            for item in remote {
                guard let id = UUID(uuidString: item.clientID),
                      let meal = MealType(rawValue: item.meal) else { continue }
                let value = FoodLog(
                    id: id,
                    date: item.loggedAt,
                    meal: meal,
                    foodName: item.foodName,
                    grams: item.grams,
                    kcal: item.kcal,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    fiber: item.fiber,
                    syncedAt: Date()
                )
                if let index = foodLogs.firstIndex(where: { $0.id == id }) {
                    foodLogs[index] = value
                } else if !localIDs.contains(id) {
                    foodLogs.append(value)
                }
            }
            foodLogs.sort { $0.date > $1.date }
        }
        if let remote = try? await APIClient.shared.fetchBodyMetrics() {
            for item in remote {
                guard let id = UUID(uuidString: item.clientID) else { continue }
                let value = BodyMetric(
                    id: id,
                    date: item.measuredAt,
                    weightKG: item.weightKG,
                    bodyFatPCT: item.bodyFatPCT,
                    waistCM: item.waistCM,
                    armCM: item.armCM,
                    thighCM: item.thighCM,
                    syncedAt: Date()
                )
                if let index = bodyMetrics.firstIndex(where: { $0.id == id }) {
                    bodyMetrics[index] = value
                } else {
                    bodyMetrics.append(value)
                }
            }
            bodyMetrics.sort { $0.date > $1.date }
            if let latest = bodyMetrics.first {
                profile.weightKG = latest.weightKG
                profile.bodyFatPCT = latest.bodyFatPCT
                profile.waistCM = latest.waistCM
                if let arm = latest.armCM, arm > 0 { profile.armCM = arm }
                if let thigh = latest.thighCM, thigh > 0 { profile.thighCM = thigh }
            }
        }
        if let remote = try? await APIClient.shared.fetchEquipmentItems() {
            for item in remote {
                guard let id = UUID(uuidString: item.clientID) else { continue }
                let value = EquipmentItem(
                    id: id,
                    name: item.name,
                    slug: item.slug,
                    muscle: item.muscle.flatMap { MuscleGroup(rawValue: $0) },
                    equipment: item.equipment.flatMap { Equipment(rawValue: $0) },
                    videoURL: nil,
                    notes: item.notes,
                    photoData: nil,
                    createdAt: item.createdAt,
                    syncedAt: Date()
                )
                if let index = equipmentLibrary.firstIndex(where: { $0.id == id }) {
                    equipmentLibrary[index] = value
                } else {
                    equipmentLibrary.append(value)
                }
            }
        }
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
        agentSessionID = nil
        agentProposal = nil
        isReplying = false
        persist()
    }

    // MARK: - Coach Agent

    /// 后台生成的周复盘会落到 AgentRun，前台只读取结果；同一周默认复用缓存。
    func refreshWeeklyReview(force: Bool = false, notifyWhenReady: Bool = false) {
        guard AuthTokenStore.shared.accessToken != nil else { return }
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

    func sendAgentChat(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chat.append(ChatMessage(role: .user, text: trimmed))
        isReplying = true
        agentProposal = nil
        persist()

        Task { @MainActor in
            defer {
                self.isReplying = false
                self.persist()
            }
            do {
                let response = try await APIClient.shared.agentChat(
                    message: trimmed,
                    sessionID: self.agentSessionID
                )
                self.agentSessionID = response.sessionID
                self.agentProposal = response.proposal
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: response.reply,
                        isSafety: false
                    )
                )
            } catch {
                let local = CoachService.reply(
                    to: trimmed,
                    profile: self.profile,
                    plan: self.plan,
                    skill: .trainer,
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
    }

    func applyAgentProposal() {
        guard let proposal = agentProposal, !isAgentWorking else { return }
        isAgentWorking = true
        Task { @MainActor in
            defer {
                self.isAgentWorking = false
                self.persist()
            }
            do {
                let updated = try await APIClient.shared.applyAgentProposal(id: proposal.id)
                self.archiveCurrentPlan()
                self.plan = updated
                if let proposed = proposal.proposed {
                    if let days = proposed.weeklyDays {
                        self.profile.weeklyDays = max(1, min(7, days))
                    }
                    if let minutes = proposed.sessionMinutes {
                        self.profile.sessionMinutes = max(15, min(180, minutes))
                    }
                }
                self.agentProposal = nil
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "计划已应用到你的正式计划。后续训练日、时长和动作会按新版本执行。"
                    )
                )
                self.toast = "已应用 Agent 计划"
                self.rescheduleNotifications()
            } catch {
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "计划草案应用失败：\(error.localizedDescription)"
                    )
                )
            }
        }
    }

    func dismissAgentProposal() {
        agentProposal = nil
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
        pendingWorkoutDeletionIDs = []
        isSyncingRemoteWorkouts = false
        weeklyReview = nil
        isReviewingWeekly = false
        reviewRefreshQueued = false
        reviewNotifyQueued = false
        useEquipmentLibraryForPlans = true
        reminderHour = 19
        reminderMinute = 0
        isAgentWorking = false
        agentSessionID = nil
        agentProposal = nil
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
        var pendingWorkoutDeletionIDs: [String]?
        var weeklyReview: AgentWeeklyReview?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            resetInMemory()
            return
        }
        var persistAfterMigration = false
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
#if DEBUG
        let debugRemoteMigration = "fitai_debug_remote_default_v2"
        if !UserDefaults.standard.bool(forKey: debugRemoteMigration) {
            useRemoteAI = true
            debugForceRemoteAI = true
            UserDefaults.standard.set(true, forKey: debugRemoteMigration)
            persistAfterMigration = true
        }
#endif
        healthKitEnabled = state.healthKitEnabled ?? false
        equipmentLibrary = state.equipmentLibrary ?? []
        bodyAnalyses = state.bodyAnalyses ?? []
        bodyMetrics = state.bodyMetrics ?? []
        bodyCheckInFrequency = state.bodyCheckInFrequency ?? .off
        bodyCheckInWeekday = state.bodyCheckInWeekday ?? 1
        bodyCheckInDay = state.bodyCheckInDay ?? 1
        bodyCheckInAnchor = state.bodyCheckInAnchor ?? Date()
        bodyCheckInDismissedDate = state.bodyCheckInDismissedDate
        pendingWorkoutDeletionIDs = state.pendingWorkoutDeletionIDs ?? []
        weeklyReview = state.weeklyReview
        useEquipmentLibraryForPlans = state.useEquipmentLibraryForPlans ?? true
        if persistAfterMigration {
            persist()
        }
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
            bodyCheckInDismissedDate: bodyCheckInDismissedDate,
            pendingWorkoutDeletionIDs: pendingWorkoutDeletionIDs,
            weeklyReview: weeklyReview
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
