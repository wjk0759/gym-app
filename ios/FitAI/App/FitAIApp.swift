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
        // 全局隐藏滚动条：iOS 设置页、聊天、列表都保持干净的沉浸式滚动。
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
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
#endif
                }
        }
    }
}
