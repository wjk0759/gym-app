import FitAIWorkoutCore
import SwiftUI
import UIKit

/// The exercise page stays intentionally clean: a looping demo with no pause
/// controls. If the video has not arrived yet, the poster or exercise text is
/// shown so an offline session never becomes a blank screen.
struct WatchActionView: View {
    let store: WatchWorkoutStore

    @State private var mediaStore = WatchMediaStore.shared
    @State private var poster: UIImage?

    var body: some View {
        let _ = mediaStore.revision
        ZStack {
            Color.black
            if let url = store.currentMediaURL {
                WatchMovieView(
                    url: url,
                    isPlaying: true,
                    loopStart: store.currentLoopStart,
                    loopEnd: store.currentLoopEnd
                )
            } else if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                overlayCaption
            } else {
                placeholder
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if let exercise = store.snapshot.currentExercise {
                Text(exercise.name)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 4)
            }
        }
        .overlay(alignment: .bottom) {
            Text("右滑回到训练")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
        }
        .task(id: store.currentPosterURL) {
            loadPoster()
        }
        .onChange(of: mediaStore.revision) { _, _ in
            loadPoster()
        }
    }

    private var overlayCaption: some View {
        VStack {
            Spacer()
            VStack(spacing: 3) {
                Text(store.snapshot.currentExercise?.name ?? "动作演示")
                    .font(.headline)
                Text(targetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 56)
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .gray.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(store.snapshot.currentExercise?.name ?? "动作演示")
                    .font(.headline)
                Text(targetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(store.currentMediaURL == nil ? "视频预载中" : "")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var targetText: String {
        guard let exercise = store.snapshot.currentExercise else {
            return "等待训练开始"
        }
        switch exercise.target {
        case .reps(let min, let max):
            return min == max ? "\(exercise.sets) 组 × \(min) 次" : "\(exercise.sets) 组 × \(min)–\(max) 次"
        case .time(let seconds):
            return "\(exercise.sets) 组 × \(seconds) 秒"
        }
    }

    private func loadPoster() {
        guard let url = store.currentPosterURL else {
            poster = nil
            return
        }
        poster = UIImage(contentsOfFile: url.path)
    }
}
