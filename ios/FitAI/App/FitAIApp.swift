import SwiftUI

@main
@MainActor
struct FitAIApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()
    @State private var subscriptions = SubscriptionManager()

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
