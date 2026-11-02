import SwiftUI

/// Coach-first Today screen.
///
/// The old Today was a dashboard with eight competing sections. This version
/// keeps one primary action (today's training), one nutrition pulse and a
/// quiet coach note. Goal, weekly review and history stay available in a
/// disclosure below, so no capability is removed.
struct HomeV2View: View {
    @Environment(AppStore.self) var store
    @Environment(WeatherStore.self) var weather

    @State var selectedDate = Date()
    @State var showCompose = false
    @State var pendingWorkoutDay: PlanDay?
    @State var workoutDay: PlanDay?
    @State var showBodyCheckIn = false
    @State var bodyCheckInManual = false
    @State var showTodayUnavailable = false
    @State var showSchedule = false
    @State var showCaptureHub = false
    @State var captureKind: CaptureKind?
    @State var didAutoPrompt = false

    var selectedDay: PlanDay? {
        guard let plan = store.plan else { return nil }
        if Calendar.current.isDateInToday(selectedDate) {
            return store.todayDay
        }
        return plan.day(on: selectedDate)
    }

    var markedKeys: Set<String> {
        Set(
            (store.plan?.days ?? []).compactMap { day in
                store.plan?.scheduledDate(for: day).map { FitnessDate.key($0) }
            }
        )
    }

    var completedKeys: Set<String> {
        Set(
            (store.plan?.days ?? []).compactMap { day in
                guard store.isPlanDayCompleted(day),
                      let date = store.plan?.scheduledDate(for: day) else { return nil }
                return FitnessDate.key(date)
            }
        )
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    if let advisory = weather.snapshot?.alertKind {
                        weatherBanner(advisory)
                    }
                    WeekStrip(
                        selectedDate: $selectedDate,
                        markedKeys: markedKeys,
                        completedKeys: completedKeys
                    )
                    coachNote
                    todaySection
                    nutritionPulse
                    quickActions
                    if !store.missedPlanDays.isEmpty {
                        missedPlanCard
                    }
                    moreSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                CaptureFAB {
                    showCaptureHub = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 88)
            }
            .fullScreenCover(isPresented: $showCompose, onDismiss: presentPendingWorkout) {
                if let day = selectedDay {
                    CustomWorkoutBuilderView(
                        title: day.title,
                        mode: .plan,
                        initialExercises: day.exercises,
                        templateDay: day
                    ) { plannedDay in
                        pendingWorkoutDay = plannedDay
                    }
                }
            }
            .fullScreenCover(item: $workoutDay) { day in
                WorkoutSessionView(
                    day: day,
                    periodMode: store.periodDay(for: day.date ?? selectedDate)?.mode
                )
            }
            .sheet(isPresented: $showBodyCheckIn) {
                BodyCheckInSheet(manual: bodyCheckInManual)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSchedule) {
                PlanScheduleView()
            }
            .sheet(isPresented: $showCaptureHub) {
                CaptureHubView { kind in
                    showCaptureHub = false
                    let feature: ProFeature? = switch kind {
                    case .food: .foodPhoto
                    case .body: .bodyPhoto
                    case .action: .videoReview
                    case .equipment: nil
                    }
                    if let feature, !store.requirePro(feature) {
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        captureKind = kind
                    }
                }
            }
            .sheet(item: $captureKind) { kind in
                captureDestination(kind)
            }
            .confirmationDialog(
                "今天没空？",
                isPresented: $showTodayUnavailable,
                titleVisibility: .visible
            ) {
                if let day = store.todayDay {
                    if let target = store.nextFreePlanDate(after: Date(), excluding: day.id) {
                        Button("顺延到 \(FitnessDate.short(target))") {
                            store.deferPlanDay(day)
                        }
                    }
                    Button("这周少练一次") {
                        store.skipPlanDay(day)
                    }
                }
                Button("调整完整训练日期") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showSchedule = true
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("顺延会保留这次训练内容；少练一次不会算作未完成。")
            }
            .task {
                store.refreshWeeklyReview()
            }
            .onAppear {
                presentLaunchIfNeeded()
                guard !didAutoPrompt else { return }
                didAutoPrompt = true
                if store.bodyCheckInDue {
                    bodyCheckInManual = false
                    showBodyCheckIn = true
                }
            }
            .onChange(of: store.bodyCheckInFrequency) { _, _ in
                if store.bodyCheckInDue {
                    bodyCheckInManual = false
                    showBodyCheckIn = true
                }
            }
            .onChange(of: store.workoutLaunchDayID) { _, dayID in
                guard let dayID,
                      let day = store.plan?.days.first(where: { $0.id == dayID }) else {
                    return
                }
                store.workoutLaunchDayID = nil
                workoutDay = day
            }
        }
    }
}
