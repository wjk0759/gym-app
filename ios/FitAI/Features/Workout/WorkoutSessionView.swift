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
    @State var adjustedExercises: [UUID: PlanExercise] = [:]
    @State var showAdjustSheet = false
    @State var adjustExerciseID: UUID?
    @State var adjustSets = 3
    @State var adjustReps = "10-12"
    @State var adjustWeight = 0.0
    @State var adjustRest = 60
    @State var weightStep = 2.5
    @State var valueEditor: WorkoutValueEditor?

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

    private var sessionScroll: some View {
        ScrollViewReader { proxy in
            AppScrollView {
                VStack(spacing: AppLayout.sectionSpacing) {
                    if let restRemaining {
                        WorkoutRestCard(
                            remaining: restRemaining,
                            total: restTotal,
                            onSkip: { self.restRemaining = nil }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Group {
                        sessionCards
                    }
                    .id(index)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(x: 22)),
                            removal: .opacity.combined(with: .offset(x: -18))
                        )
                    )
                }
                .appPagePadding()
                .padding(.vertical, 16)
                .padding(.bottom, 24)
                .appReadableContent()
                .id("session-top")
                .motionAnimation(Motion.smooth, value: index)
                .motionAnimation(Motion.quick, value: restRemaining != nil)
            }
            .onChange(of: index) { _, _ in
                withAnimation(Motion.smooth) {
                    proxy.scrollTo("session-top", anchor: .top)
                }
            }
            .onChange(of: restRemaining != nil) { _, isResting in
                guard isResting else { return }
                withAnimation(Motion.smooth) {
                    proxy.scrollTo("session-top", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private var sessionCards: some View {
        if let exercise = currentExercise {
            WorkoutSessionExerciseCard(
                exercise: exercise,
                index: index,
                exerciseCount: activeDay.exercises.count,
                periodMode: periodMode
            )
            WorkoutSetCard(
                exercise: exercise,
                done: completedSets(for: exercise),
                lastSet: store.lastSet(for: exercise.slug),
                bestSet: store.bestSet(for: exercise.slug),
                weight: $weight,
                reps: $reps,
                rpe: $rpe,
                weightStep: $weightStep,
                onAdjust: { openAdjustSheet(exercise) },
                onEditWeight: { valueEditor = .weight },
                onEditReps: { valueEditor = .reps },
                onUndoLast: {
                    guard !logs.isEmpty else { return }
                    logs.removeLast()
                    restRemaining = nil
                },
                isLastSetCurrent: {
                    guard completedSets(for: exercise) > 0, let last = logs.last else { return false }
                    return last.slug == exercise.slug
                }()
            )
            WorkoutTrainingTipCard(
                exercise: exercise,
                lastSet: store.lastSet(for: exercise.slug)
            )
        } else {
            WorkoutSessionSummaryCard(
                logs: logs,
                plannedTotalSets: plannedTotalSets,
                isFullSession: isFullSession,
                durationMinutes: durationMinutes,
                feeling: $feeling,
                notes: $notes
            )
        }
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

                sessionScroll
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
                prepare(currentExercise)
                activeStartedAt = Date()
                WatchSyncManager.shared.activate()
                WatchSyncManager.shared.activeWorkoutDayID = day.id
                Task {
                    await syncWatchBootstrap()
                }
                drainWatchInbox()
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
                    for: .fitaiWatchBootstrapRequested
                )
            ) { notification in
                guard let dayID = notification.object as? UUID, dayID == day.id else {
                    return
                }
                Task {
                    await syncWatchBootstrap()
                }
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
        return WorkoutSessionActionBar(
            exercise: exercise,
            done: done,
            nextTitle: nextTitle,
            setSummary: exercise.map { setSummary(for: $0) } ?? "",
            onSkip: { advance() },
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
