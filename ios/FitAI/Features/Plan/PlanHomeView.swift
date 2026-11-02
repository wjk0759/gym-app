import SwiftUI

/// The record tab as a printed training journal.
///
/// Everything the old screen could do is still here: month calendar, schedule
/// changes, plan editing, workout history, period mode, progress and the plan
/// version list. The difference is hierarchy: the month reads as a cover, the
/// calendar as a date grid, and one selected day as a page.
struct PlanHomeView: View {
    @Environment(AppStore.self) var store

    @State var selectedDate = Date()
    @State var visibleMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()
    @State var showRegenerate = false
    @State var showHistory = false
    @State var showSchedule = false
    @State var sessionSheet: SessionSheet?
    @State var editingDay: PlanDay?
    @State var workoutDay: PlanDay?
    @State var dayScrollRequest = 0

    struct SessionSheet: Identifiable {
        let id = UUID()
        let session: WorkoutSession
        let isNew: Bool
    }

    struct MonthStats {
        var sessions = 0
        var foodDays = 0
        var volume: Double = 0
        var minutes = 0
        var completedPlanDays = 0
        var plannedDays = 0

        var completion: Double {
            plannedDays > 0 ? Double(completedPlanDays) / Double(plannedDays) : 0
        }
    }

    struct DayStatus {
        let text: String
        let accent: Color
        let filled: Bool
    }

    var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                AppScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        topBar
                        header
                        quickActions

                        if store.isGenerating {
                            generatingCard
                        } else {
                            monthCover
                            calendarCard(plan: store.plan)
                            selectedDayCard(plan: store.plan)
                                .id("selected-day")
                            trainingDataCard

                            if let plan = store.plan {
                                planSummaryCard(plan)
                                if !store.hasProAccess {
                                    ProUpsellCard(feature: .trainingPlan) {
                                        store.requestPro(.trainingPlan)
                                    }
                                }
                            } else {
                                emptyPlanCard
                            }
                        }
                    }
                    .appPagePadding()
                    .appReadableContent()
                    .padding(.top, 2)
                    .padding(.bottom, 28)
                }
                .background(AppBackground())
                .navigationTitle("")
                .navigationBarHidden(true)
                .sheet(isPresented: $showHistory) {
                    PlanHistoryView()
                }
                .sheet(item: $sessionSheet) { item in
                    WorkoutDetailView(session: item.session, isNew: item.isNew)
                }
                .sheet(isPresented: $showSchedule) {
                    PlanScheduleView()
                }
                .fullScreenCover(item: $editingDay) { day in
                    PlanEditorView(day: day)
                }
                .fullScreenCover(item: $workoutDay) { day in
                    WorkoutSessionView(
                        day: day,
                        periodMode: store.periodDay(for: day.date ?? selectedDate)?.mode
                    )
                }
                .confirmationDialog(
                    "重新生成计划？",
                    isPresented: $showRegenerate,
                    titleVisibility: .visible
                ) {
                    Button("重新生成", role: .destructive) {
                        store.generatePlan()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("当前计划会被归档，历史训练记录保留。")
                }
                .onChange(of: dayScrollRequest) { _, _ in
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo("selected-day", anchor: .top)
                    }
                }
            }
        }
    }
}
