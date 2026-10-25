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

            EquipmentScanView()
                .tabItem {
                    Label("器械", systemImage: "camera.viewfinder")
                }

            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.crop.circle")
                }
        }
        .tint(Theme.accent)
        .toolbarBackground(Theme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
