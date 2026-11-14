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
    /// 服务端改课；撤销时调用服务端并替换返回的计划日。
    case serverWorkoutAction(actionID: String, planID: UUID, dayID: UUID)
    /// 教练写入的饮食记录；撤销时删除同一 action 的整组记录。
    case foodLogAction(actionID: String)
    /// 教练修改/删除已有饮食记录；撤销后重新拉取服务端结果。
    case foodLogEditAction(actionID: String)
    /// 教练补录的训练；撤销时删除该 action 创建的训练。
    case workoutAction(actionID: String)
    /// 教练修改/删除训练；撤销后重新拉取服务端训练历史。
    case workoutEditAction(actionID: String)
    /// 计划餐跳过/恢复；撤销时恢复服务端计划餐状态。
    case mealPlanStateAction(actionID: String)
    /// 旧版本地改课；撤销时恢复改课前的整份计划。
    case plan(TrainingPlan)
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
    /// Onboarding plan waiting for the user's confirmation.
    var pendingPlanPreview: TrainingPlan?
    /// User tapped "稍后" on the first-plan preview. Keep it so Home can resume.
    var deferredPlanPreview: TrainingPlan?
    /// Set when the current plan was produced locally and has not reached the
    /// server yet. Retried on the next user-data sync.
    var planNeedsServerSync = false
    var planHistory: [TrainingPlan] = []
    var sessions: [WorkoutSession] = []
    /// 当前训练中的本地草稿；只保留一个，避免同一天出现多份进度。
    var workoutDraft: WorkoutDraft?
    var chat: [ChatMessage] = []
    var selectedTab = 0
    /// Transient handoff from Today to the Record tab. Not persisted.
    var pendingRecordDate: Date?
    var coachContext: String?
    var coachVisualMemory: CoachVisualMemory?
    /// Set when the server rejects a normal coach turn with
    /// COACH_QUOTA_EXHAUSTED. It makes the inline Pro card appear immediately,
    /// before the refreshed /me/access snapshot lands.
    var coachQuotaExhausted = false
    var planAdjustmentRequested = false
    var planAdjustmentStage = 0
    var planAdjustmentIssue = ""
    var planAdjustmentDetail = ""
    var planAdjustmentCategory = ""
    var planAdjustmentProposal: PlanAdjustmentProposal?
    var foodLogs: [FoodLog] = []
    /// Last server-confirmed targets for the current day. Home reads this so its
    /// nutrition ring matches the weekly plan instead of a flat local estimate.
    var dailyNutritionTargets: NutritionTargets?
    var dailyNutritionTargetsKey: String?
    /// Food log client IDs deleted locally but not yet acknowledged by the API.
    var pendingFoodDeletionIDs: [String] = []
    /// Food log client IDs edited locally but not yet accepted by the API.
    /// Prevents a cloud pull from restoring the old values.
    var pendingFoodUpdateIDs: [String] = []
    var customFoods: [FoodItem] = []
    /// Saved food-library items shown above search results in AddFoodView.
    var favoriteFoods: [FoodItem] = []
    var dislikedSlugs: Set<String> = []
    var equipmentLibrary: [EquipmentItem] = []
    /// 通用器械勾选（徒手/哑铃/杠铃...）。
    var selectedUniversalSlugs: [String] = ["bodyweight"]
    /// 计划模式：true = 只用我的器械；false = 优先我的器械，不足回退。
    var strictEquipmentMode = false
    var bodyAnalyses: [BodyAnalysis] = []
    var bodyMetrics: [BodyMetric] = []
    var bodyCheckInFrequency: BodyCheckInFrequency = .off
    var bodyCheckInWeekday = 1
    var bodyCheckInDay = 1
    var bodyCheckInAnchor = Date()
    var bodyCheckInDismissedDate: String? = nil
    var isGenerating = false
    var isReplying = false
    @ObservationIgnored var lastPlanGeneratedAt: Date?
    @ObservationIgnored var pendingPlanIdempotencyKey: String?
    var isSyncingWorkouts = false
    var isSyncingRemoteWorkouts = false
    var isSyncingUserData = false
    var scheduleSyncRequested = false
    @ObservationIgnored var draftPersistWorkItem: DispatchWorkItem?
    @ObservationIgnored var agentChatTask: Task<Void, Never>?
    @ObservationIgnored var agentChatWatchdog: Task<Void, Never>?
    @ObservationIgnored var agentChatRequestID: UUID?
    @ObservationIgnored var coachPhotoTask: Task<Void, Never>?
    @ObservationIgnored var coachPhotoWatchdog: Task<Void, Never>?
    @ObservationIgnored var coachPhotoRequestID: UUID?
    /// 已从本地删除、但服务端 DELETE 尚未成功的训练记录 ID。
    var pendingWorkoutDeletionIDs: [String] = []
    var isAgentWorking = false
    var agentSessionID: UUID?
    var coachSessionID: UUID?
    var coachSession: CoachSessionState?
    var coachPending: CoachPendingState?
    var coachReceipt: CoachReceipt?
    var coachUndoActionID: String?
    var coachBodyBefore: BodyMetric?
    var coachWeightBefore: Double?
    var coachPlanBefore: TrainingPlan?
    var coachInbox: [CoachInboxItem] = []
    var coachHistoryHasMore = false
    var coachHistoryCursor: String?
    var isLoadingCoachHistory = false
    var coachEntryPrompt: String?
    var isCoachControlWorking = false
    var agentRunID: String?
    var agentProposal: AgentPlanProposal?
    var agentActions: [AgentAction] = []
    var pendingDraft: AgentPendingDraft?
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
    var restLiveActivityEnabled = true
    var restNotificationsEnabled = true
    var useRemoteAI = AppConfig.useRemoteAI
    /// Server snapshot, StoreKit fallback and paywall coordinator live here so
    /// AppStore stays a data/sync store instead of the entitlement source.
    @ObservationIgnored let access = FeatureAccessStore()
    /// 仅用于 Debug 预览 DeepSeek；正式包不会暴露出开关。
    var healthKitEnabled = false

    var currentUserID: String? = AuthTokenStore.shared.userID
    // 状态较大时 JSON 编码和原子落盘会阻塞主线程；写入串行放到 utility 队列。
    let planGeneration = PlanGenerationService()
    let workoutSync = WorkoutSyncService()
    let nutrition = NutritionService()

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

    func resetAll() {
        flushPersistence()
        try? FileManager.default.removeItem(at: fileURL)
        resetInMemory()
        NotificationScheduler.shared.cancelAll()
        Task { @MainActor in
            await RestLiveActivityManager.shared.endAll()
        }
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
        pendingPlanPreview = nil
        deferredPlanPreview = nil
        planNeedsServerSync = false
        planHistory = []
        sessions = []
        workoutDraft = nil
        chat = []
        foodLogs = []
        dailyNutritionTargets = nil
        dailyNutritionTargetsKey = nil
        pendingFoodDeletionIDs = []
        pendingFoodUpdateIDs = []
        customFoods = []
        favoriteFoods = []
        dislikedSlugs = []
        notificationsEnabled = false
        restLiveActivityEnabled = true
        restNotificationsEnabled = true
        useRemoteAI = AppConfig.useRemoteAI
        healthKitEnabled = false
        equipmentLibrary = []
        selectedUniversalSlugs = ["bodyweight"]
        strictEquipmentMode = false
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
        reminderHour = 19
        reminderMinute = 0
        isAgentWorking = false
        agentSessionID = nil
        coachSessionID = nil
        coachSession = nil
        coachPending = nil
        coachReceipt = nil
        coachUndoActionID = nil
        coachBodyBefore = nil
        coachWeightBefore = nil
        coachPlanBefore = nil
        coachInbox = []
        coachHistoryHasMore = false
        coachHistoryCursor = nil
        isLoadingCoachHistory = false
        isCoachControlWorking = false
        agentRunID = nil
        agentProposal = nil
        agentActions = []
        pendingDraft = nil
        coachVisualMemory = nil
        coachQuotaExhausted = false
        isExecutingAgentActions = false
        workoutLaunchDayID = nil
        pendingRecordDate = nil
        pendingRoute = nil
        lastAgentRetryText = nil
        lastAgentRetrySkill = .trainer
        pendingUndo = nil
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
            NSLog("Jiaolian state read failed: %@", error.localizedDescription)
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
            NSLog("Jiaolian state decode failed; backup=%@ error=%@", backup.lastPathComponent, error.localizedDescription)
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
        pendingPlanPreview = state.pendingPlanPreview
        deferredPlanPreview = state.deferredPlanPreview
        planNeedsServerSync = state.planNeedsServerSync ?? false
        planHistory = state.planHistory ?? []
        sessions = state.sessions
        workoutDraft = state.workoutDraft
        chat = state.chat
        agentSessionID = state.agentSessionID
        coachSessionID = state.coachSessionID
        agentActions = state.agentActions ?? []
        pendingDraft = state.pendingDraft
        foodLogs = state.foodLogs ?? []
        dailyNutritionTargets = state.dailyNutritionTargets
        dailyNutritionTargetsKey = state.dailyNutritionTargetsKey
        pendingFoodDeletionIDs = state.pendingFoodDeletionIDs ?? []
        pendingFoodUpdateIDs = state.pendingFoodUpdateIDs ?? []
        customFoods = state.customFoods ?? []
        favoriteFoods = state.favoriteFoods ?? []
        dislikedSlugs = Set(state.dislikedSlugs ?? [])
        reminderHour = state.reminderHour
        reminderMinute = state.reminderMinute
        notificationsEnabled = state.notificationsEnabled
        restLiveActivityEnabled = state.restLiveActivityEnabled ?? true
        restNotificationsEnabled = state.restNotificationsEnabled ?? true
        useRemoteAI = state.useRemoteAI ?? AppConfig.useRemoteAI
#if DEBUG
        let debugRemoteMigration = "fitai_debug_remote_default_v2"
        if !UserDefaults.standard.bool(forKey: debugRemoteMigration) {
            useRemoteAI = true
            UserDefaults.standard.set(true, forKey: debugRemoteMigration)
            persistAfterMigration = true
        }
#endif
        healthKitEnabled = state.healthKitEnabled ?? false
        equipmentLibrary = state.equipmentLibrary ?? []
        selectedUniversalSlugs = state.selectedUniversalSlugs ?? ["bodyweight"]
        strictEquipmentMode = state.strictEquipmentMode ?? false
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
            pendingPlanPreview: pendingPlanPreview,
            deferredPlanPreview: deferredPlanPreview,
            planNeedsServerSync: planNeedsServerSync,
            planHistory: planHistory,
            sessions: sessions,
            workoutDraft: workoutDraft,
            chat: chat,
            agentSessionID: agentSessionID,
            coachSessionID: coachSessionID,
            agentActions: agentActions,
            pendingDraft: pendingDraft,
            foodLogs: foodLogs,
            dailyNutritionTargets: dailyNutritionTargets,
            dailyNutritionTargetsKey: dailyNutritionTargetsKey,
            pendingFoodDeletionIDs: pendingFoodDeletionIDs,
            pendingFoodUpdateIDs: pendingFoodUpdateIDs,
            customFoods: customFoods,
            favoriteFoods: favoriteFoods,
            dislikedSlugs: Array(dislikedSlugs).sorted(),
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            notificationsEnabled: notificationsEnabled,
            restLiveActivityEnabled: restLiveActivityEnabled,
            restNotificationsEnabled: restNotificationsEnabled,
            useRemoteAI: useRemoteAI,
            healthKitEnabled: healthKitEnabled,
            equipmentLibrary: equipmentLibrary,
            selectedUniversalSlugs: selectedUniversalSlugs,
            strictEquipmentMode: strictEquipmentMode,
            bodyAnalyses: bodyAnalyses,
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

    private struct PersistedState: Codable {
        var profile: UserProfile
        var plan: TrainingPlan?
        var pendingPlanPreview: TrainingPlan?
        var deferredPlanPreview: TrainingPlan?
        var planNeedsServerSync: Bool?
        var planHistory: [TrainingPlan]?
        var sessions: [WorkoutSession]
        var workoutDraft: WorkoutDraft?
        var chat: [ChatMessage]
        var agentSessionID: UUID?
        var coachSessionID: UUID?
        var agentActions: [AgentAction]?
        var pendingDraft: AgentPendingDraft?
        var foodLogs: [FoodLog]?
        var dailyNutritionTargets: NutritionTargets?
        var dailyNutritionTargetsKey: String?
        var pendingFoodDeletionIDs: [String]?
        var pendingFoodUpdateIDs: [String]?
        var customFoods: [FoodItem]?
        var favoriteFoods: [FoodItem]?
        var dislikedSlugs: [String]?
        var reminderHour: Int
        var reminderMinute: Int
        var notificationsEnabled: Bool
        var restLiveActivityEnabled: Bool?
        var restNotificationsEnabled: Bool?
        var useRemoteAI: Bool?
        var healthKitEnabled: Bool?
        var equipmentLibrary: [EquipmentItem]?
        var selectedUniversalSlugs: [String]?
        var strictEquipmentMode: Bool?
        var bodyAnalyses: [BodyAnalysis]?
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
}
