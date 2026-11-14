import SwiftUI

enum AppRoute: String, Identifiable, Hashable {
    case trainingSchedule = "training_schedule"
    case nutrition
    case bodyCheckIn = "body_checkin"
    case profileEdit = "profile_edit"
    case workoutHistory = "workout_history"
    case agentMemory = "agent_memory"
    case periodSchedule = "period_schedule"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainingSchedule: return "训练日期"
        case .nutrition: return "饮食记录"
        case .bodyCheckIn: return "身体打卡"
        case .profileEdit: return "编辑档案"
        case .workoutHistory: return "训练历史"
        case .agentMemory: return "AI 长期记忆"
        case .periodSchedule: return "经期安排"
        }
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    @State private var todayPath = NavigationPath()
    @State private var recordPath = NavigationPath()
    @State private var discoverPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            HomeV2View(navigationPath: $todayPath)
                .background {
                    TabBarReselectObserver {
                        resetTabPaths()
                    }
                    .frame(width: 0, height: 0)
                }
                .tag(AppTab.today.rawValue)
                .tabItem {
                    Label("今日", systemImage: "figure.strengthtraining.traditional")
                }

            PlanHomeView(navigationPath: $recordPath)
                .tag(AppTab.record.rawValue)
                .tabItem {
                    Label("记录", systemImage: "chart.xyaxis.line")
                }

            CoachChatView()
                .tag(AppTab.coach.rawValue)
                .tabItem {
                    Label("教练", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(store.coachInboxUnreadCount)

            DiscoverView(navigationPath: $discoverPath)
                .tag(AppTab.discover.rawValue)
                .tabItem {
                    Label("发现", systemImage: "square.grid.2x2")
                }

            ProfileView(navigationPath: $profilePath)
                .tag(AppTab.profile.rawValue)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.cobalt)
        .toolbarBackground(Theme.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sensoryFeedback(.selection, trigger: store.selectedTab)
        .onChange(of: store.selectedTab) { _, _ in
            resetTabPaths()
        }
        .sheet(item: $store.pendingRoute) { route in
            destination(for: route)
        }
    }

    /// A tab is a top-level section: switching tabs always returns the target
    /// section to its root, while keeping each root's own state (scroll
    /// position, coach draft, selected date) untouched.
    private func resetTabPaths() {
        todayPath = NavigationPath()
        recordPath = NavigationPath()
        discoverPath = NavigationPath()
        profilePath = NavigationPath()
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .trainingSchedule:
            PlanScheduleView()
        case .nutrition:
            NavigationStack {
                NutritionView()
            }
        case .bodyCheckIn:
            BodyCheckInSheet(manual: true)
                .presentationDetents([.medium, .large])
        case .profileEdit:
            NavigationStack {
                ProfileEditView()
            }
        case .workoutHistory:
            NavigationStack {
                WorkoutHistoryView()
            }
        case .agentMemory:
            AgentMemoryView()
        case .periodSchedule:
            PeriodScheduleView()
        }
    }
}

