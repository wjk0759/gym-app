import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("今日", systemImage: "figure.strengthtraining.traditional")
                }

            PlanHomeView()
                .tabItem {
                    Label("计划", systemImage: "calendar")
                }

            CoachChatView()
                .tabItem {
                    Label("教练", systemImage: "bubble.left.and.bubble.right")
                }

            NavigationStack {
                EquipmentLibraryView()
            }
            .tabItem {
                Label("器械", systemImage: "dumbbell")
            }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.accent)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
