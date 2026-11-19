import SwiftUI
import UIKit
import UserNotifications

/// App 入口：创建全局 store/auth/subscription/weather，注入环境和根视图。
/// 业务状态不在这里，RootView 只负责登录/onboarding/主界面的路由。
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

        // Native glass bars: system-managed blur, so scrolling stays cheap.
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabAppearance.backgroundColor = .clear
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        DiagnosticsReporter.shared.start()
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
