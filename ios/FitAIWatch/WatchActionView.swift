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
    @State private var videoFailed = false

    var body: some View {
        let _ = mediaStore.revision
        ZStack {
            WatchTheme.canvas.ignoresSafeArea()
            if let url = store.currentMediaURL, !videoFailed {
                WatchMovieView(
                    url: url,
                    isPlaying: true,
                    loopStart: store.currentLoopStart,
                    loopEnd: store.currentLoopEnd,
                    onFailure: { videoFailed = true }
                )
                .ignoresSafeArea()
            } else if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .ignoresSafeArea()
                overlayCaption
            } else {
                placeholder
                    .ignoresSafeArea()
            }
        }
        .overlay(alignment: .top) {
            WatchPageDots(index: 1)
                .padding(.top, 4)
        }
        .overlay(alignment: .topLeading) {
            if let exercise = store.snapshot.currentExercise {
                Text(exercise.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchTheme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        WatchTheme.surface.opacity(0.92),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(WatchTheme.stroke, lineWidth: 1)
                    }
                    .padding(.top, 16)
                    .padding(.leading, 2)
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                Text("右滑回到训练")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(WatchTheme.ink.opacity(0.82))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(WatchTheme.surface.opacity(0.88), in: Capsule())
            .padding(.bottom, 14)
        }
        .task(id: store.currentPosterURL) {
            loadPoster()
        }
        .onChange(of: mediaStore.revision) { _, _ in
            if store.currentMediaURL != nil {
                videoFailed = false
            }
            loadPoster()
        }
        .onChange(of: store.currentMediaURL) { _, _ in
            videoFailed = false
        }
    }

    private var overlayCaption: some View {
        VStack {
            Spacer()
            Text(targetText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WatchTheme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(WatchTheme.surface.opacity(0.82), in: Capsule())
                .padding(.bottom, 58)
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [WatchTheme.surface, WatchTheme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(WatchTheme.primary)
                Text(targetText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WatchTheme.ink)
                Label(
                    videoFailed ? "视频不可用，按文字提示训练" : "等待 iPhone 预载",
                    systemImage: videoFailed
                        ? "exclamationmark.triangle"
                        : "arrow.down.circle"
                )
                .font(.caption2)
                .foregroundStyle(WatchTheme.secondary)
            }
            .padding(.bottom, 42)
        }
    }

    private var targetText: String {
        guard let exercise = store.snapshot.currentExercise else {
            return "等待训练开始"
        }
        switch exercise.target {
        case .reps(let min, let max):
            return min == max
                ? "\(exercise.sets) 组 × \(min) 次"
                : "\(exercise.sets) 组 × \(min)–\(max) 次"
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
