import SwiftUI

/// 记录 Tab 的训练手账首页。
/// 月历、计划摘要、选中日详情和入口都从这里组装；
/// 计划写入/改期/生成由 AppStore 和子页面处理，本 View 不直接写库。
struct PlanHomeView: View {
    @Environment(AppStore.self) var store

    @Binding var navigationPath: NavigationPath

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

    struct DayStatus {
        let text: String
    }

    var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { proxy in
                AppScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        quickActions
                        equipmentReplanBanner

                        if store.isGenerating {
                            generatingCard
                        } else {
                            calendarCard(plan: store.plan)
                            selectedDayCard(plan: store.plan)
                                .id("selected-day")

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
                    .appPageTopPadding()
                }
                .appTabBarClearance()
                .background(AppBackground())
                .navigationTitle("训练手账")
                .navigationBarTitleDisplayMode(.inline)
                .appTabDestinations()
                .toolbar {
                    if !Calendar.current.isDateInToday(selectedDate) {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("今天") {
                                goToToday()
                            }
                            .font(AppType.body)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                store.openCoach(prompt: "帮我调整这一天的训练：")
                            } label: {
                                Label("问教练", systemImage: "bubble.left.and.bubble.right")
                            }
                            Button {
                                showHistory = true
                            } label: {
                                Label("计划历史", systemImage: "clock.arrow.circlepath")
                            }
                            if store.plan != nil {
                                Button(role: .destructive) {
                                    if store.requirePro(.trainingPlan) {
                                        showRegenerate = true
                                    }
                                } label: {
                                    Label("重新生成", systemImage: "arrow.clockwise")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
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
                .onChange(of: store.pendingRecordDate) { _, _ in
                    consumePendingRecordDate()
                }
                .onChange(of: store.selectedTab) { _, tab in
                    guard tab == AppTab.today.rawValue else { return }
                    store.pendingRecordDate = nil
                    selectedDate = calendar.startOfDay(for: Date())
                    visibleMonth = startOfMonth(Date())
                }
                .onAppear {
                    consumePendingRecordDate()
                }
                .task(id: selectedDate) {
                    await store.refreshNutritionTargets(for: selectedDate)
                }
                .onChange(of: store.revision(.diet)) { _, _ in
                    Task {
                        await store.refreshNutritionTargets(for: selectedDate)
                    }
                }
            }
        }
    }
}
