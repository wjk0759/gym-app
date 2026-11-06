import SwiftUI

/// The watch has exactly two surfaces: workout controls and the exercise demo.
/// Training is the default page; swiping left opens the demo, swiping right
/// returns to training.
struct WatchRootView: View {
    @State private var store = WatchWorkoutStore()
    @State private var page: WatchPage = .training
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if store.isPro {
                pager
            } else {
                WatchLockedView {
                    store.refreshEntitlement()
                }
            }
        }
        .onAppear {
            WatchSyncManager.shared.store = store
            WatchSyncManager.shared.activate()
            store.onSnapshotChange = { snapshot in
                WatchSyncManager.shared.send(snapshot: snapshot)
            }
        }
    }

    private var pager: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            HStack(spacing: 0) {
                WatchTrainingView(store: store)
                    .frame(width: width)
                WatchActionView(store: store)
                    .frame(width: width)
            }
            .offset(x: -CGFloat(page.rawValue) * width + dragOffset)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: page)
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 44
                        if value.translation.width < -threshold {
                            page = .action
                        } else if value.translation.width > threshold {
                            page = .training
                        }
                        dragOffset = 0
                    }
            )
        }
    }
}

private enum WatchPage: Int {
    case training = 0
    case action = 1
}
