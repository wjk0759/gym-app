import SwiftUI
import FitAIWorkoutCore

/// The exercise page stays intentionally clean: a looping demo with no pause
/// controls. Playback is wired to the real media pipeline in a later step.
struct WatchActionView: View {
    private var movieURL: URL? {
        Bundle.main.url(forResource: "sample_loop", withExtension: "mp4")
    }

    var body: some View {
        ZStack {
            if let movieURL {
                WatchMovieView(url: movieURL, isPlaying: true)
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
