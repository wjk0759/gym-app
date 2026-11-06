import SwiftUI
import FitAIWorkoutCore

/// The watch has exactly two surfaces: the workout controls and the exercise
/// demo. The training page is the default; swiping left opens the demo, and
/// swiping right returns to training.
struct WatchRootView: View {
    #if DEBUG
    @State private var isPro = true
    #else
    @State private var isPro = false
    #endif

    @State private var page: WatchPage = .training
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        Group {
            if isPro {
                pager
            } else {
                WatchLockedView {
                    // Entitlement sync is wired in a later step. Keeping this
                    // action explicit avoids a dead-looking locked screen.
                }
            }
        }
    }

    private var pager: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            HStack(spacing: 0) {
                WatchTrainingView()
                    .frame(width: width)
                WatchActionView()
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
