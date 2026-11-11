import SwiftUI

/// The clips keep their native studio background. The 1:1 media box is
/// transparent, so the page background shows around non-square clips.
private enum DemoPanelStyle {
    static let secondaryText = Theme.inkSolid.opacity(0.62)
    static let placeholder = Theme.inkSolid.opacity(0.30)
    static let border = Theme.inkSolid.opacity(0.08)
}

/// Inline looping exercise demo for the iPhone workout screen.
///
/// The media box is a transparent 1:1 surface. Each clip keeps its native
/// aspect ratio and is centred; the leftover area shows the page background.
struct ExerciseAnimationCard: View {
    let exercise: PlanExercise
    let medias: [ExerciseMediaItem]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var videoFailed = false
    @State private var resolvedVideoURL: URL?
    @State private var posterLocalURL: URL?

    private var media: ExerciseMediaItem { medias[0] }

    private var canPlayVideo: Bool {
        media.phoneURL != nil && !reduceMotion && !videoFailed
    }

    private var playURL: URL? {
        resolvedVideoURL ?? media.phoneURL
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if canPlayVideo, let url = playURL {
                ExerciseMediaBox(
                    url: url,
                    onFailure: { videoFailed = true }
                )
            } else {
                posterContent
            }

            Text("动作示范")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Theme.inkSolid.opacity(0.9),
                    in: Capsule()
                )
                .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(DemoPanelStyle.border, lineWidth: 1)
        }
        .accessibilityLabel("\(exercise.displayName)动作循环示范")
        .onChange(of: exercise.id) { _, _ in
            videoFailed = false
        }
        .task(id: media.id) {
            resolvedVideoURL = media.phoneURL
            posterLocalURL = media.posterURL
            if let cached = await ExerciseMediaCache.shared.ensureVideoCached(media) {
                resolvedVideoURL = cached
            }
            if let cached = await ExerciseMediaCache.shared.ensurePosterCached(media) {
                posterLocalURL = cached
            }
        }
    }

    @ViewBuilder
    private var posterContent: some View {
        if let posterURL = posterLocalURL ?? media.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    placeholder
                case .empty:
                    ProgressView()
                        .tint(DemoPanelStyle.placeholder)
                @unknown default:
                    placeholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(DemoPanelStyle.placeholder)
            Text("动作演示准备中")
                .font(.caption.weight(.medium))
                .foregroundStyle(DemoPanelStyle.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
