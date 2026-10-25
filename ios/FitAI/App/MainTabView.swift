import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            TrainingHubView()
                .tabItem {
                    Label("训练", systemImage: "figure.strengthtraining.traditional")
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
