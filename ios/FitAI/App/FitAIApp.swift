import SwiftUI
import UIKit

@main
@MainActor
struct FitAIApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()
    @State private var subscriptions = SubscriptionManager()

    init() {
        // 全局隐藏滚动条：iOS 设置页、聊天、列表都保持干净的沉浸式滚动。
        UIScrollView.appearance().showsVerticalScrollIndicator = false
        UIScrollView.appearance().showsHorizontalScrollIndicator = false
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .environment(subscriptions)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    await subscriptions.load()
                }
        }
    }
}
