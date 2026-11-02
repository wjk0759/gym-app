import Foundation
import Observation

struct AgentUndoAction: Identifiable {
    let id: String
    let title: String
    let actionType: String
    let expiresAt: Date
    let runID: String?
    let state: AgentUndoState
}

indirect enum AgentUndoState {
    case schedule(
        planID: UUID,
        dayID: UUID,
        previousDate: Date?,
        previousWeekday: Int,
        previousWeekIndex: Int,
        previousSkippedAt: Date?
    )
    case bodyMetric(
        metricID: UUID,
        previousMetric: BodyMetric?,
        previousProfile: UserProfile
    )
    case profile(UserProfile)
    /// 一次 Agent 动作卡可能包含多天操作，撤销时要一起恢复。
    case batch([AgentUndoState])
}

@Observable
final class AppStore {
    static let chatRequestTimeoutNanoseconds: UInt64 = 45_000_000_000
    static let agentTimeoutNotice = "这次回复等待太久了，可能是网络或模型服务较慢。问题已保留，可以点重试。"
    static let legacyTimeoutNotice = "这次回复等待太久了，可能是网络或模型服务较慢。可以稍后再试。"
    static let photoTimeoutNotice = "这张照片的分析等待太久了，可能是网络或视觉服务较慢。可以重新拍一张，或先用文字描述动作和不舒服的位置。"
    static let chatTimeoutNotices: Set<String> = [
        agentTimeoutNotice,
        legacyTimeoutNotice,
        photoTimeoutNotice
    ]

    var profile = UserProfile()
    var plan: TrainingPlan?
    var planHistory: [TrainingPlan] = []
    var sessions: [WorkoutSession] = []
    /// 当前训练中的本地草稿；只保留一个，避免同一天出现多份进度。
    var workoutDraft: WorkoutDraft?
    var chat: [ChatMessage] = []
    var selectedTab = 0
    var coachContext: String?
    var coachVisualMemory: CoachVisualMemory?
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
    @ObservationIgnored private var lastPlanGeneratedAt: Date?
    @ObservationIgnored private var pendingPlanIdempotencyKey: String?
    var isSyncingWorkouts = false
    var isSyncingRemoteWorkouts = false
    var isSyncingUserData = false
    var scheduleSyncRequested = false
    @ObservationIgnored private var draftPersistWorkItem: DispatchWorkItem?
    @ObservationIgnored var agentChatTask: Task<Void, Never>?
    @ObservationIgnored var agentChatWatchdog: Task<Void, Never>?
    @ObservationIgnored var agentChatRequestID: UUID?
    @ObservationIgnored var coachPhotoTask: Task<Void, Never>?
    @ObservationIgnored var coachPhotoWatchdog: Task<Void, Never>?
    @ObservationIgnored var coachPhotoRequestID: UUID?
    @ObservationIgnored var legacyChatTask: Task<Void, Never>?
    @ObservationIgnored var legacyChatWatchdog: Task<Void, Never>?
    @ObservationIgnored var legacyChatRequestID: UUID?
    /// 已从本地删除、但服务端 DELETE 尚未成功的训练记录 ID。
    var pendingWorkoutDeletionIDs: [String] = []
    var isAgentWorking = false
    var agentSessionID: UUID?
    var agentRunID: String?
    var agentProposal: AgentPlanProposal?
    var agentActions: [AgentAction] = []
    var dietWeekPlan: RemoteDietWeek?
    var coachEquipmentScanRequested = false
    var coachBodyAnalysisRequested = false
    /// 从发现页/相机入口带回教练页的待发送图片；不直接发送。
    var pendingCoachAttachmentData: [Data] = []
    var coachEquipmentResult: EquipmentScanResult?
    var isExecutingAgentActions = false
    var workoutLaunchDayID: UUID?
    var pendingRoute: AppRoute?
    var lastAgentRetryText: String?
    var lastAgentRetrySkill: CoachSkill = .trainer
    @ObservationIgnored var lastAgentRequestID: UUID?
    var pendingUndo: AgentUndoAction?
    var weeklyReview: AgentWeeklyReview?
    var isReviewingWeekly = false
    var reviewRefreshQueued = false
    var reviewNotifyQueued = false
    var toast: String?
    var reminderHour = 19
    var reminderMinute = 0
    var notificationsEnabled = false
    var useRemoteAI = AppConfig.useRemoteAI
    /// Server snapshot, StoreKit fallback and paywall coordinator live here so
    /// AppStore stays a data/sync store instead of the entitlement source.
    @ObservationIgnored let access = FeatureAccessStore()
    /// 仅用于 Debug 预览 DeepSeek；正式包不会暴露出开关。
    var healthKitEnabled = false

    var debugForceRemoteAI: Bool {
        get { access.debugForcePro }
        set { access.debugForcePro = newValue }
    }

    var currentUserID: String? = AuthTokenStore.shared.userID
    // 状态较大时 JSON 编码和原子落盘会阻塞主线程；写入串行放到 utility 队列。
    private let persistenceQueue = DispatchQueue(
        label: "com.fitai.appstore.persistence",
        qos: .utility
    )
    private let persistenceLock = NSLock()
    private var pendingPersistedState: PersistedState?
    private var pendingPersistedURL: URL?
    private var persistenceDrainScheduled = false

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
                    async let profileSync = APIClient.shared.syncProfile(snapshot)
                    async let goalSync = APIClient.shared.syncGoal(snapshot)
                    try await profileSync
                    _ = try? await goalSync
                    var generated = try await APIClient.shared.generatePlan(
                        force: force,
                        onboarding: onboarding,
                        equipmentSlugs: librarySlugs,
                        split: snapshot.split,
                        focus: focusAreas.map(\.rawValue),
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
                    var fallback = PlanGenerator.generate(
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
            var generated = PlanGenerator.generate(
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
    private func consumeOnboardingTrialIfNeeded() async {
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

    func clearPreferences() {
        dislikedSlugs.removeAll()
        persist()
    }

    // MARK: - 训练与对话

    func record(
        day: PlanDay,
        sets: [SetLog],
        durationMinutes: Int,
        feeling: Int,
        notes: String? = nil,
        plannedSets: Int? = nil
    ) {
        let cleanNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = WorkoutSession(
            dayTitle: day.title,
            durationMinutes: durationMinutes,
            feeling: feeling,
            notes: (cleanNotes?.isEmpty ?? true) ? nil : cleanNotes,
            sets: sets,
            programDayID: day.id.uuidString,
            plannedSets: plannedSets
        )
        if workoutDraft?.dayID == day.id {
            workoutDraft = nil
        }
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

    // MARK: - 训练草稿

    func draft(for dayID: UUID) -> WorkoutDraft? {
        guard let workoutDraft, workoutDraft.dayID == dayID else { return nil }
        return workoutDraft
    }

    /// 当前草稿对应的计划日；计划已重新生成时可能找不到。
    var draftPlanDay: PlanDay? {
        guard let draft = workoutDraft, let plan else { return nil }
        return plan.days.first { $0.id == draft.dayID }
    }

    func saveWorkoutDraft(_ draft: WorkoutDraft, persistImmediately: Bool = false) {
        let isNewDraft = workoutDraft?.dayID != draft.dayID
        workoutDraft = draft

        if persistImmediately || isNewDraft {
            draftPersistWorkItem?.cancel()
            draftPersistWorkItem = nil
            persist()
            return
        }

        // 训练中每完成一组就全量编码落盘会放大 I/O。首次保存立即落盘，
        // 后续最多每 10 秒合并一次；暂停/切后台/退出时再强制落盘。
        guard draftPersistWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.draftPersistWorkItem = nil
            self.persist()
        }
        draftPersistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    func clearWorkoutDraft(dayID: UUID? = nil) {
        if let dayID {
            guard workoutDraft?.dayID == dayID else { return }
        }
        workoutDraft = nil
        persist()
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
        cancelActiveChatRequest()
        access.clear()
        access.paywall.dismiss()
        draftPersistWorkItem?.cancel()
        draftPersistWorkItem = nil
        profile = UserProfile()
        plan = nil
        planHistory = []
        sessions = []
        workoutDraft = nil
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
        scheduleSyncRequested = false
        weeklyReview = nil
        isReviewingWeekly = false
        reviewRefreshQueued = false
        reviewNotifyQueued = false
        useEquipmentLibraryForPlans = true
        reminderHour = 19
        reminderMinute = 0
        isAgentWorking = false
        agentSessionID = nil
        agentRunID = nil
        agentProposal = nil
        agentActions = []
        coachVisualMemory = nil
        isExecutingAgentActions = false
        workoutLaunchDayID = nil
        pendingRoute = nil
        lastAgentRetryText = nil
        lastAgentRetrySkill = .trainer
        pendingUndo = nil
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
        var workoutDraft: WorkoutDraft?
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
        var coachVisualMemory: CoachVisualMemory?
    }

    private func load() {
        let started = CFAbsoluteTimeGetCurrent()
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            resetInMemory()
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            NSLog("FitAI state read failed: %@", error.localizedDescription)
            resetInMemory()
            return
        }

        let state: PersistedState
        do {
            state = try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            // Never silently overwrite an unreadable state file: keep a
            // timestamped copy so a user can recover a bad migration/build.
            let backup = url.deletingLastPathComponent().appendingPathComponent(
                "\(url.deletingPathExtension().lastPathComponent)-corrupt-\(Int(Date().timeIntervalSince1970)).json"
            )
            try? FileManager.default.copyItem(at: url, to: backup)
            NSLog("FitAI state decode failed; backup=%@ error=%@", backup.lastPathComponent, error.localizedDescription)
            resetInMemory()
            return
        }
#if DEBUG
        if data.count > 200_000 {
            NSLog(
                "STRESS load %.1fms %.2fMB",
                (CFAbsoluteTimeGetCurrent() - started) * 1000,
                Double(data.count) / 1_048_576
            )
        }
#endif
        var persistAfterMigration = false
        profile = state.profile
        plan = state.plan
        planHistory = state.planHistory ?? []
        sessions = state.sessions
        workoutDraft = state.workoutDraft
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
        coachVisualMemory = state.coachVisualMemory
        useEquipmentLibraryForPlans = state.useEquipmentLibraryForPlans ?? true
        if persistAfterMigration {
            persist()
        }
    }

    func persist() {
        draftPersistWorkItem?.cancel()
        draftPersistWorkItem = nil
        let state = PersistedState(
            profile: profile,
            plan: plan,
            planHistory: planHistory,
            sessions: sessions,
            workoutDraft: workoutDraft,
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
            weeklyReview: weeklyReview,
            coachVisualMemory: coachVisualMemory
        )
        let url = fileURL

        // 连续交互（滑杆、滚轮、打卡）会高频调用 persist。
        // 只保留最新快照，后台队列合并成一次编码 + 一次落盘。
        persistenceLock.lock()
        pendingPersistedState = state
        pendingPersistedURL = url
        let shouldSchedule = !persistenceDrainScheduled
        if shouldSchedule {
            persistenceDrainScheduled = true
        }
        persistenceLock.unlock()

        guard shouldSchedule else { return }
        persistenceQueue.async { [weak self] in
            self?.drainPersistence()
        }
    }

    private func drainPersistence() {
        while true {
            persistenceLock.lock()
            guard let state = pendingPersistedState,
                  let url = pendingPersistedURL else {
                persistenceDrainScheduled = false
                persistenceLock.unlock()
                return
            }
            pendingPersistedState = nil
            pendingPersistedURL = nil
            persistenceLock.unlock()

            let started = CFAbsoluteTimeGetCurrent()
            guard let data = try? JSONEncoder().encode(state) else { continue }
            let encodedAt = CFAbsoluteTimeGetCurrent()
            try? data.write(to: url, options: .atomic)
            let finishedAt = CFAbsoluteTimeGetCurrent()

#if DEBUG
            if ProcessInfo.processInfo.environment["FITAI_QA_STRESS"] == "1", data.count > 200_000 {
                NSLog(
                    "STRESS persist encode=%.1fms write=%.1fms total=%.1fms size=%.2fMB",
                    (encodedAt - started) * 1000,
                    (finishedAt - encodedAt) * 1000,
                    (finishedAt - started) * 1000,
                    Double(data.count) / 1_048_576
                )
            }
#endif
        }
    }

    /// 进入后台或切换账号前调用，确保已排队的写入完成。
    func flushPersistence() {
        if draftPersistWorkItem != nil {
            draftPersistWorkItem?.cancel()
            draftPersistWorkItem = nil
            persist()
        }
        persistenceQueue.sync {
            persistenceLock.lock()
            let state = pendingPersistedState
            let url = pendingPersistedURL
            pendingPersistedState = nil
            pendingPersistedURL = nil
            persistenceDrainScheduled = false
            persistenceLock.unlock()

            if let state, let url,
               let data = try? JSONEncoder().encode(state) {
                try? data.write(to: url, options: .atomic)
            }
        }
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
