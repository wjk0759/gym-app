import Combine
import FitAIWorkoutCore
import SwiftUI
import UIKit

struct WorkoutSessionView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase

    let day: PlanDay
    let periodMode: PeriodTrainingMode?

    init(day: PlanDay, periodMode: PeriodTrainingMode? = nil) {
        self.day = day
        self.periodMode = periodMode
    }

    @State var index = 0
    @State var page: WorkoutSessionPage = .data
    @State var logs: [SetLog] = []
    @State var weight: Double = 0
    @State var reps: Int = 10
    @State var rpe: Double = 7.5
    @State var restRemaining: Int?
    @State var restTotal: Double = 1
    @State var feeling = 4
    @State var notes = ""
    @State var elapsedSeconds: TimeInterval = 0
    @State var activeStartedAt = Date()
    @State var resumedExercises: [PlanExercise]?
    @State var didLoadDraft = false
    @State var didFinish = false
    @State var showResumeBanner = false
    @State var showExitConfirm = false
    @State var showEmptySaveAlert = false
    @State var watchNotice: String?
    @State var adjustedExercises: [UUID: PlanExercise] = [:]
    @State var showAdjustSheet = false
    @State var adjustExerciseID: UUID?
    @State var adjustSets = 3
    @State var adjustReps = "10-12"
    @State var adjustWeight = 0.0
    @State var adjustRest = 60
    @State var weightStep = 2.5
    @State var valueEditor: WorkoutValueEditor?
    @State var mediaStore = ExerciseMediaStore()
    @State var showInstructions = false
    @State var substitutionTarget: Exercise?
    @State var substitutionNotice: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @ViewBuilder
    private var resumeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(Theme.cobalt)
            Text("已恢复上次进度：\(logs.count) 组")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 4)
            Button("知道了") {
                withAnimation(Motion.quick) {
                    showResumeBanner = false
                }
            }
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Theme.cobalt.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.cobalt.opacity(0.20), lineWidth: 1)
        )
        .appPagePadding()
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    @ViewBuilder
    private var substitutionBanner: some View {
        if let substitutionNotice {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.cobalt)
                Text(substitutionNotice)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Theme.cobalt.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.cobalt.opacity(0.20), lineWidth: 1)
            }
            .appPagePadding()
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var sessionContent: some View {
        Group {
            if let exercise = currentExercise {
                VStack(spacing: 0) {
                    WorkoutSessionExerciseHeader(
                        exercise: exercise,
                        periodMode: periodMode,
                        onAdjust: { openAdjustSheet(exercise) }
                    )

                    WorkoutSessionPageTabs(selection: $page)

                    TabView(selection: $page) {
                        dataPage(exercise)
                            .tag(WorkoutSessionPage.data)

                        demoPage(exercise)
                            .tag(WorkoutSessionPage.demo)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                Theme.background.opacity(0),
                                Theme.background
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 16)
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                summaryScroll
            }
        }
    }

    private func dataPage(_ exercise: PlanExercise) -> some View {
        WorkoutSessionDataPage(
            exercise: exercise,
            logs: logs,
            lastSet: store.lastSet(for: exercise.slug),
            bestSet: store.bestSet(for: exercise.slug),
            rpe: $rpe,
            canSubstitute: !isWatchLed
                && exercise.exercise != nil
                && exercise.exercise?.equipment != .bodyweight
                && completedSets(for: exercise) < exercise.sets,
            canUndo: logs.last?.slug == exercise.slug,
            onUseLast: {
                guard let last = store.lastSet(for: exercise.slug) else { return }
                weight = last.weightKG
                reps = last.reps
            },
            onSubstitute: {
                guard let info = exercise.exercise else { return }
                substitutionTarget = info
            },
            onUndo: {
                guard !logs.isEmpty else { return }
                if isWatchLed {
                    let command = WorkoutCommand.undoLastSet(
                        .init(at: Date(), source: .phone)
                    )
                    _ = sendToWatch(command)
                    return
                }
                logs.removeLast()
                restRemaining = nil
            }
        )
    }

    private func demoPage(_ exercise: PlanExercise) -> some View {
        WorkoutSessionDemoPage(
            exercise: exercise,
            medias: mediaStore.items(for: exercise.slug),
            isPlaying: page == .demo,
            lastSet: store.lastSet(for: exercise.slug),
            showInstructions: $showInstructions
        )
    }

    private var summaryScroll: some View {
        ScrollView {
            WorkoutSessionSummaryCard(
                logs: logs,
                plannedTotalSets: plannedTotalSets,
                isFullSession: isFullSession,
                durationMinutes: durationMinutes,
                feeling: $feeling,
                notes: $notes
            )
            .appPagePadding()
            .padding(.vertical, 16)
            .appReadableContent()
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WorkoutProgressHeader(
                    dayTitle: day.title,
                    logsCount: logs.count,
                    totalSets: plannedTotalSets,
                    index: index,
                    exerciseCount: activeDay.exercises.count
                )

                if showResumeBanner {
                    resumeBanner
                }

                if substitutionNotice != nil {
                    substitutionBanner
                }

                sessionContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
            .background(AppBackground())
            .navigationTitle("训练中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentExercise != nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("暂停") { showExitConfirm = true }
                    }
                }
            }
            .keyboardDoneToolbar()
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                loadDraftIfNeeded()
                prefetchExerciseMedia()
                prepare(currentExercise)
                activeStartedAt = Date()
                WatchSyncManager.shared.activate()
                WatchSyncManager.shared.activeWorkoutDayID = day.id
                Task {
                    await syncWatchBootstrap()
                }
                drainWatchInbox()
            }
            .onChange(of: index) { _, _ in
                showInstructions = false
                page = .data
                prefetchExerciseMedia()
            }
            .onDisappear {
                if WatchSyncManager.shared.activeWorkoutDayID == day.id {
                    WatchSyncManager.shared.activeWorkoutDayID = nil
                }
                saveDraftIfNeeded(persistImmediately: true)
                store.flushPersistence()
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    elapsedSeconds = currentElapsed
                    activeStartedAt = Date()
                    prefetchExerciseMedia()
                    drainWatchInbox()
                } else {
                    saveDraftIfNeeded(persistImmediately: true)
                    store.flushPersistence()
                }
            }
            .onReceive(timer) { _ in
                tickRest()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .fitaiWatchSessionUpdated
                )
            ) { notification in
                guard let envelope = notification.object as? WatchSessionEnvelope,
                      envelope.snapshot.programDayID == day.id else {
                    return
                }
                applyWatchSnapshot(envelope)
                WatchSyncManager.shared.acknowledgeInbox(
                    sessionID: envelope.sessionID,
                    revision: envelope.snapshot.revision
                )
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .fitaiWatchCommandFailed
                )
            ) { _ in
                watchNotice = "手表连接中断，请稍后重试"
            }

            .confirmationDialog(
                "暂停或结束训练？",
                isPresented: $showExitConfirm,
                titleVisibility: .visible
            ) {
                Button("暂停，稍后继续") { pauseAndExit() }
                Button("结束并保存", role: .destructive) { finish() }
                Button("继续训练", role: .cancel) {}
            } message: {
                Text("暂停会保存已完成的 \(logs.count) 组，下次进来接着练；结束并保存会生成训练记录。")
            }
            .alert(
                "手表训练",
                isPresented: Binding(
                    get: { watchNotice != nil },
                    set: { if !$0 { watchNotice = nil } }
                )
            ) {
                Button("知道了", role: .cancel) { watchNotice = nil }
            } message: {
                Text(watchNotice ?? "")
            }
            .alert("还没有训练记录", isPresented: $showEmptySaveAlert) {
                Button("继续训练", role: .cancel) {}
                Button("放弃并退出", role: .destructive) {
                    store.clearWorkoutDraft(dayID: day.id)
                    didFinish = true
                    dismiss()
                }
            } message: {
                Text("至少完成一组后再保存，避免产生一条 0 组的空训练记录。")
            }
            .sheet(isPresented: $showAdjustSheet) {
                adjustSheet
            }
            .sheet(item: $substitutionTarget) { target in
                WorkoutSubstitutionSheet(
                    current: target,
                    profile: store.profile,
                    equipmentLibrary: store.equipmentLibrary,
                    universalSlugs: store.selectedUniversalSlugs,
                    strictEquipment: store.strictEquipmentMode,
                    todaySlugs: Set(activeDay.exercises.map(\.slug)),
                    lastSet: { store.lastSet(for: $0) },
                    onSelect: { applySubstitution($0) },
                    onSkip: { skipRemainingSets() }
                )
            }
            .sheet(item: $valueEditor) { editor in
                WorkoutSessionValueEntrySheet(
                    editor: editor,
                    weight: $weight,
                    reps: $reps
                )
            }
        }
    }

    // MARK: - 当前动作

    var currentExercise: PlanExercise? {
        guard activeDay.exercises.indices.contains(index) else { return nil }
        return effectiveExercise(activeDay.exercises[index])
    }

    /// One batch request covers the whole day; switching exercises then reads
    /// from the in-memory cache instead of hitting the network again.
    func prefetchExerciseMedia() {
        let slugs = activeDay.exercises.map(\.slug)
        guard !slugs.isEmpty else { return }
        Task { await mediaStore.prefetch(slugs: slugs) }
    }

    /// 恢复草稿时使用草稿里的动作列表，避免用户自定义过的训练顺序被计划原顺序覆盖。
    var activeDay: PlanDay {
        var value = day
        if let resumedExercises {
            value.exercises = resumedExercises
        }
        return value
    }

    var plannedTotalSets: Int {
        activeDay.exercises.reduce(0) { partial, exercise in
            partial + max(1, effectiveExercise(exercise).sets)
        }
    }

    func effectiveExercise(_ exercise: PlanExercise) -> PlanExercise {
        var value = adjustedExercises[exercise.id] ?? exercise
        if let sessionSets = value.sessionSets {
            value.sets = max(0, sessionSets)
            if periodMode == .light, let weight = value.weightKG, weight > 0 {
                value.weightKG = ((weight * 0.8) * 2).rounded() / 2
            }
            return value
        }
        if periodMode == .light {
            value.sets = max(2, value.sets - 1)
            if let weight = value.weightKG, weight > 0 {
                value.weightKG = ((weight * 0.8) * 2).rounded() / 2
            }
        }
        return value
    }

    func completedSets(for exercise: PlanExercise) -> Int {
        logs.filter { $0.slug == exercise.slug }.count
    }

    var actionBar: some View {
        let exercise = currentExercise
        let done = exercise.map { completedSets(for: $0) } ?? 0
        return WorkoutSessionLoggerBar(
            exercise: exercise,
            done: done,
            nextTitle: nextTitle,
            weight: $weight,
            reps: $reps,
            weightStep: $weightStep,
            restRemaining: restRemaining,
            restTotal: restTotal,
            onEditWeight: { valueEditor = .weight },
            onEditReps: { valueEditor = .reps },
            onSkipRest: { skipRest() },
            onSkipRemaining: { skipRemainingSets() },
            onComplete: {
                guard let exercise else { return }
                completeSet(exercise)
            },
            onAdvance: { advance() },
            onFinish: { finish() }
        )
    }

    var nextTitle: String {
        index < activeDay.exercises.count - 1 ? "下一个动作" : "查看训练总结"
    }

    // MARK: - 总结

    var isFullSession: Bool {
        let completed = store.finalizedCompletedSets(for: day) + logs.filter(\.completed).count
        return completed >= plannedTotalSets
    }

    var currentElapsed: TimeInterval {
        elapsedSeconds + Date().timeIntervalSince(activeStartedAt)
    }

    var durationMinutes: Int {
        max(1, Int(currentElapsed / 60))
    }
}
