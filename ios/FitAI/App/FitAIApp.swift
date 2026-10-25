import SwiftUI

@main
@MainActor
struct FitAIApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(auth)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
