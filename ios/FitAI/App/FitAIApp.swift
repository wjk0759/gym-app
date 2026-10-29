import SwiftUI
import UIKit
import UserNotifications

@main
@MainActor
struct FitAIApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()
    @State private var subscriptions = SubscriptionManager()
    @State private var weather: WeatherStore

    init() {
        // Let iOS 26 provide the native Liquid Glass navigation/tab bar chrome.
        // Custom appearance proxies here would override the system material.
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        _weather = State(initialValue: WeatherStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .environment(subscriptions)
                .environment(weather)
                .task {
                    await subscriptions.load()
#if DEBUG
                    StressHarness.runIfRequested()
                    FrameHitchMonitor.shared.startIfRequested()
#endif
                }
        }
    }
}
