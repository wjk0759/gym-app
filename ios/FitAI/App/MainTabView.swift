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
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            HomeView()
                .environment(\.weatherAnimationActive, store.selectedTab == 0)
                .tag(0)
                .tabItem {
                    Label("今日", systemImage: "figure.strengthtraining.traditional")
                }

            PlanHomeView()
                .environment(\.weatherAnimationActive, store.selectedTab == 1)
                .tag(1)
                .tabItem {
                    Label("记录", systemImage: "calendar")
                }

            CoachChatView()
                .environment(\.weatherAnimationActive, store.selectedTab == 2)
                .tag(2)
                .tabItem {
                    Label("教练", systemImage: "bubble.left.and.bubble.right")
                }

            DiscoverView()
                .environment(\.weatherAnimationActive, store.selectedTab == 3)
                .tag(3)
                .tabItem {
                    Label("发现", systemImage: "square.grid.2x2")
                }

            ProfileView()
                .environment(\.weatherAnimationActive, store.selectedTab == 4)
                .tag(4)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(atmosphere.accent(for: colorScheme))
        .sensoryFeedback(.selection, trigger: store.selectedTab)
        .sheet(item: $store.pendingRoute) { route in
            destination(for: route)
        }
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
