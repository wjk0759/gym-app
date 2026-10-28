import Combine
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(WeatherStore.self) private var weather
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var splashPulse = false
    @State private var phaseNow = Date()

    private let phaseTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        let atmosphere = WeatherAtmosphere.make(snapshot: weather.snapshot, date: phaseNow)

        ZStack {
            AppBackground()

            Group {
                if auth.isRestoring {
                    splash
                        .transition(.opacity)
                } else if !auth.isAuthenticated {
                    LoginView()
                        .transition(screenTransition)
                } else if store.profile.isOnboarded {
                    MainTabView()
                        .transition(screenTransition)
                } else {
                    OnboardingView()
                        .transition(screenTransition)
                }
            }
        }
        .environment(\.weatherAtmosphere, atmosphere)
        .tint(atmosphere.accent(for: colorScheme))
        .overlay {
            if atmosphere.isPrecipitation {
                RainGlassOverlay(intensity: atmosphere.precipitationIntensity)
                    .ignoresSafeArea()
            }
        }
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: auth.isRestoring)
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: auth.isAuthenticated)
        .animation(Motion.resolved(Motion.gentle, reduceMotion: reduceMotion), value: store.profile.isOnboarded)
        .animation(Motion.resolved(.easeInOut(duration: 0.9), reduceMotion: reduceMotion), value: atmosphere.isPrecipitation)
        .sensoryFeedback(.success, trigger: auth.isAuthenticated) { _, isAuthenticated in
            isAuthenticated
        }
        .task {
            store.isPro = subscriptions.isPro
            await auth.restoreIfNeeded()
            store.switchUser(auth.userID)
            if auth.isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.refreshWeeklyReview()
                store.syncPendingUserData()
            }
            activateWeatherIfNeeded()
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
        .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
            store.switchUser(auth.userID)
            if isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.refreshWeeklyReview()
                store.syncPendingUserData()
            }
            activateWeatherIfNeeded()
        }
        .onChange(of: auth.userID) { _, userID in
            store.switchUser(userID)
            if auth.isAuthenticated {
                enableRemoteMode()
                store.syncPendingWorkouts()
                store.syncRemoteWorkouts()
                store.refreshWeeklyReview()
                store.syncPendingUserData()
                activateWeatherIfNeeded()
            }
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
    }

    private var screenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)),
            removal: .opacity
        )
    }

    private var splash: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 72, height: 72)
                    .shadow(color: Theme.accent.opacity(0.45), radius: 24, y: 8)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
            }
            .scaleEffect(splashPulse ? 1.05 : 1)
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: splashPulse
            )
            .onAppear { splashPulse = true }

            Text("练途")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            ProgressView()
                .tint(Theme.accent)
            Text("正在恢复登录状态…")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .transition(.opacity)
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
