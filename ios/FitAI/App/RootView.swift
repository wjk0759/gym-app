import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if store.profile.isOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.profile.isOnboarded)
    }
}
