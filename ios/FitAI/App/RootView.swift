import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AppBackground()

            if auth.isRestoring {
                splash
            } else if !auth.isAuthenticated {
                LoginView()
                    .transition(.opacity)
            } else if store.profile.isOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isAuthenticated)
        .animation(.easeInOut(duration: 0.25), value: store.profile.isOnboarded)
        .task {
            store.isPro = subscriptions.isPro
            await auth.restoreIfNeeded()
            store.switchUser(auth.userID)
            if auth.isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.syncPendingUserData()
            }
        }
        .onChange(of: subscriptions.isPro) { _, isPro in
            store.isPro = isPro
        }
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            store.switchUser(auth.userID)
            if isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.syncPendingUserData()
            }
        }
        .onChange(of: auth.userID) { _, userID in
            store.switchUser(userID)
            if auth.isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.syncPendingUserData()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.flushPersistence()
            } else if auth.isAuthenticated {
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.syncPendingUserData()
            }
        }
    }

    private var splash: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 72, height: 72)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            Text("练途")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            ProgressView()
                .tint(Theme.accent)
            Text("正在恢复登录状态…")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func enableRemoteMode() {
        guard !store.useRemoteAI else { return }
        store.useRemoteAI = true
        store.persist()
    }
}
