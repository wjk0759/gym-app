import Combine
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(WeatherStore.self) private var weather
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phaseNow = Date()
    @State private var syncedUserID: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private let phaseTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        let atmosphere = WeatherAtmosphere.make(snapshot: weather.snapshot, date: phaseNow)

        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if auth.isRestoring && !qaBypassAuth {
                    splash
                        .transition(.opacity)
                } else if !auth.isAuthenticated && !qaBypassAuth {
                    LoginView()
                        .transition(screenTransition)
                } else if store.profile.isOnboarded || qaBypassAuth {
                    MainTabView()
                        .transition(screenTransition)
                } else {
                    OnboardingView()
                        .transition(screenTransition)
                }
            }
        }
        .environment(\.weatherAtmosphere, atmosphere)
        .overlay(alignment: .top) {
            if let message = store.toast, !message.isEmpty {
                ToastBanner(message: message)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion), value: store.toast)
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: auth.isRestoring)
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: auth.isAuthenticated)
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: store.profile.isOnboarded)
        .sensoryFeedback(.success, trigger: auth.isAuthenticated) { _, isAuthenticated in
            isAuthenticated
        }
        .task {
            store.isPro = subscriptions.isPro
            await auth.restoreIfNeeded()
            refreshSession()
        }
        .onReceive(phaseTimer) { date in
            phaseNow = date
            if auth.isAuthenticated, store.profile.isOnboarded {
                weather.refreshIfNeeded()
                Task { @MainActor in
                    await weather.evaluateCurrentAlertIfNeeded()
                }
            }
        }
        .onChange(of: subscriptions.isPro) { _, isPro in
            store.isPro = isPro
        }
        .onChange(of: auth.isAuthenticated) { _, _ in
            refreshSession()
        }
        .onChange(of: auth.userID) { _, _ in
            refreshSession()
        }
        .onChange(of: store.profile.isOnboarded) { _, isOnboarded in
            if isOnboarded {
                activateWeatherIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.flushPersistence()
            } else {
                phaseNow = Date()
                if auth.isAuthenticated {
                    store.syncPendingWorkouts()
                    store.syncRemoteWorkouts()
                    store.refreshWeeklyReview()
                    store.syncPendingUserData()
                    activateWeatherIfNeeded()
                }
            }
        }
        .onChange(of: store.toast) { _, message in
            toastDismissTask?.cancel()
            guard let message, !message.isEmpty else { return }
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_800_000_000)
                guard !Task.isCancelled, store.toast == message else { return }
                withAnimation(Motion.resolved(Motion.quick, reduceMotion: reduceMotion)) {
                    store.toast = nil
                }
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
            toastDismissTask = nil
        }
    }

    private var screenTransition: AnyTransition {
        .opacity
    }

    private var splash: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.accentFill)
                    .frame(width: 72, height: 72)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(Theme.onAccentFill)
            }

            Text("练途")
                .font(AppType.hero)
                .foregroundStyle(Theme.primaryText)
            ProgressView()
                .tint(Theme.accentText)
            Text("正在恢复登录状态…")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .transition(.opacity)
    }

    private var qaBypassAuth: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FITAI_QA_BYPASS_AUTH"] == "1"
        #else
        false
        #endif
    }

    private func refreshSession() {
        store.switchUser(auth.userID)
        guard auth.isAuthenticated else {
            syncedUserID = nil
            return
        }
        guard syncedUserID != auth.userID else {
            activateWeatherIfNeeded()
            return
        }
        syncedUserID = auth.userID
        enableRemoteMode()
        store.syncPendingWorkouts()
        store.syncRemoteWorkouts()
        store.refreshWeeklyReview()
        store.syncPendingUserData()
        activateWeatherIfNeeded()
    }

    private func activateWeatherIfNeeded() {
        guard auth.isAuthenticated, store.profile.isOnboarded else { return }
        weather.activate()
    }

    private func enableRemoteMode() {
        guard !store.useRemoteAI else { return }
        store.useRemoteAI = true
        store.persist()
    }
}
