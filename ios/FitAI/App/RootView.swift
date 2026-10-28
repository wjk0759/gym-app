import Combine
import SwiftUI
import UIKit

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
    @State private var keyboardVisible = false
    @State private var syncedUserID: String?

    private let phaseTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some View {
        let atmosphere = WeatherAtmosphere.make(snapshot: weather.snapshot, date: phaseNow)

        ZStack {
            Theme.background.ignoresSafeArea()

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
        .environment(\.keyboardVisible, keyboardVisible)
        .tint(atmosphere.accent(for: colorScheme))
        // 全屏水珠层会持续参与合成；雨天效果保留在背景天空里，避免影响滚动和输入。
        .overlay {
            KeyboardDismissInstaller()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                keyboardVisible = false
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .transition(.opacity)
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
