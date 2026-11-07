import SwiftUI

/// The sample/licensed clips sit on a light studio background, so the media
/// panel keeps a fixed white surface and fixed dark copy in both appearances.
private enum DemoPanelStyle {
    static let secondaryText = Theme.inkSolid.opacity(0.62)
    static let placeholder = Theme.inkSolid.opacity(0.30)
    static let border = Theme.inkSolid.opacity(0.08)
}

/// Inline looping exercise demo for the iPhone workout screen.
///
/// The media panel stays light because the licensed demo clips currently use a
/// white studio background. The badge and expand affordance use the app's
/// ink/lime system instead of forcing a black surface.
struct ExerciseAnimationCard: View {
    let exercise: PlanExercise
    let media: ExerciseMediaItem

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var showFullScreen = false
    @State private var videoFailed = false

    private var canPlayVideo: Bool {
        media.phoneURL != nil && !reduceMotion && !videoFailed
    }

    var body: some View {
        Button {
            showFullScreen = true
        } label: {
            ZStack {
                Color.white

                if canPlayVideo, let url = media.phoneURL {
                    SilentLoopingVideoPlayer(
                        url: url,
                        isPlaying: scenePhase == .active && !showFullScreen,
                        onFailure: { videoFailed = true }
                    )
                    .allowsHitTesting(false)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(10)
                } else {
                    posterContent
                }

                VStack {
                    HStack(alignment: .top) {
                        Text("动作示范")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Theme.inkSolid.opacity(0.9),
                                in: Capsule()
                            )

                        Spacer(minLength: 4)

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Theme.inkSolid.opacity(0.88),
                                in: Circle()
                            )
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
            }
            .frame(height: 236)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DemoPanelStyle.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exercise.displayName)动作循环示范")
        .onChange(of: exercise.id) { _, _ in
            videoFailed = false
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            ExerciseAnimationFullScreen(
                exercise: exercise,
                media: media
            )
        }
    }

    @ViewBuilder
    private var posterContent: some View {
        if let posterURL = media.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(10)
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

private struct ExerciseAnimationFullScreen: View {
    let exercise: PlanExercise
    let media: ExerciseMediaItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPlaying = true
    @State private var videoFailed = false

    private var canPlayVideo: Bool {
        media.phoneURL != nil && !reduceMotion && !videoFailed
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("动作示范")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.inkSolid, in: Capsule())

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Theme.inkSolid, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ZStack {
                            Color.white

                            if canPlayVideo, let url = media.phoneURL {
                                SilentLoopingVideoPlayer(
                                    url: url,
                                    isPlaying: isPlaying
                                        && scenePhase == .active,
                                    onFailure: { videoFailed = true }
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .padding(8)
                            } else if let posterURL = media.posterURL {
                                AsyncImage(url: posterURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .padding(8)
                                    default:
                                        fullScreenPlaceholder
                                    }
                                }
                            } else {
                                fullScreenPlaceholder
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 24,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 24,
                                style: .continuous
                            )
                            .strokeBorder(
                                DemoPanelStyle.border,
                                lineWidth: 1
                            )
                        }

                        if canPlayVideo {
                            HStack {
                                Spacer()
                                Button {
                                    isPlaying.toggle()
                                } label: {
                                    Label(
                                        isPlaying ? "暂停" : "继续",
                                        systemImage: isPlaying
                                            ? "pause.fill"
                                            : "play.fill"
                                    )
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.onPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Theme.primary,
                                        in: Capsule()
                                    )
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(exercise.displayName)
                                .font(AppType.title)
                                .foregroundStyle(Theme.inkSolid)
                            Text(exercise.targetText)
                                .font(AppType.caption.weight(.semibold))
                                .foregroundStyle(DemoPanelStyle.secondaryText)
                            if let instructions = exercise.exercise?.instructions,
                               !instructions.isEmpty {
                                Text(instructions)
                                    .font(AppType.callout)
                                    .foregroundStyle(DemoPanelStyle.secondaryText)
                                    .lineSpacing(2)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                isPlaying = false
            }
        }
        .preferredColorScheme(.light)
    }

    private var fullScreenPlaceholder: some View {
        VStack(spacing: 9) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(DemoPanelStyle.placeholder)
            Text("动作演示准备中")
                .font(.callout.weight(.medium))
                .foregroundStyle(DemoPanelStyle.secondaryText)
        }
    }
}
