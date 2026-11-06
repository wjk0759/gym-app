import FitAIWorkoutCore
import SwiftUI

/// The watch has exactly two surfaces: workout controls and the exercise demo.
/// Training is the default page; swiping left opens the demo, swiping right
/// returns to training. Voice lives inside the training page as a sheet so the
/// two-page model stays intact.
struct WatchRootView: View {
    @State private var store = WatchWorkoutStore()
    @State private var page: WatchPage = .training
    @State private var dragOffset: CGFloat = 0
    @State private var showVoice = false

    var body: some View {
        Group {
            if store.canTrainNow {
                pager
            } else {
                WatchLockedView {
                    Task { await store.refreshEntitlementFromServer() }
                }
            }
        }
        .onAppear {
            WatchSyncManager.shared.store = store
            WatchSyncManager.shared.activate()
            store.onSnapshotChange = { snapshot in
                WatchSyncManager.shared.send(snapshot: snapshot)
            }
            Task {
                await store.refreshEntitlementFromServer()
                syncHealthSession(with: store.snapshot.status)
            }
        }
        .onChange(of: store.canTrainNow) { _, canTrain in
            if !canTrain {
                WatchHealthSession.shared.stop()
            }
        }
        .onChange(of: store.snapshot.status) { _, status in
            syncHealthSession(with: status)
        }
        .onChange(of: store.bootstrap?.programDayID) { _, _ in
            syncHealthSession(with: store.snapshot.status)
        }
        .sheet(isPresented: $showVoice) {
            NavigationStack {
                WatchVoiceView(context: store.voiceContext)
            }
        }
    }

    private var pager: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            HStack(spacing: 0) {
                WatchTrainingView(store: store) {
                    showVoice = true
                }
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

    private func syncHealthSession(with status: WorkoutSessionStatus) {
        guard store.canTrainNow, !store.snapshot.exercises.isEmpty else {
            WatchHealthSession.shared.stop()
            return
        }
        switch status {
        case .active:
            Task {
                await WatchHealthSession.shared.startIfNeeded()
                WatchHealthSession.shared.resume()
            }
        case .paused:
            WatchHealthSession.shared.pause()
        case .finished, .discarded:
            WatchHealthSession.shared.stop()
        }
    }
}

private enum WatchPage: Int {
    case training = 0
    case action = 1
}
