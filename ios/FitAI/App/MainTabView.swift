import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            HomeView()
                .tag(0)
                .tabItem {
                    Label("今日", systemImage: "figure.strengthtraining.traditional")
                }

            PlanHomeView()
                .tag(1)
                .tabItem {
                    Label("计划", systemImage: "calendar")
                }

            CoachChatView()
                .tag(2)
                .tabItem {
                    Label("教练", systemImage: "bubble.left.and.bubble.right")
                }

            NavigationStack {
                EquipmentPickerView()
            }
            .tag(3)
            .tabItem {
                Label("器械", systemImage: "dumbbell")
            }

            ProfileView()
                .tag(4)
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
