import SwiftUI

/// The exercise page stays intentionally clean: a looping demo with no pause
/// controls. The store resolves the current exercise clip from the preload.
struct WatchActionView: View {
    let store: WatchWorkoutStore

    var body: some View {
        ZStack {
            if let url = store.currentMediaURL {
                WatchMovieView(url: url, isPlaying: true)
            } else {
                placeholder
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("右滑回到训练")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .gray.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text("动作演示")
                    .font(.headline)
                Text("等待动作素材")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
