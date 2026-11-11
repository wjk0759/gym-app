import SwiftUI

/// 1:1 media surface for the native-aspect exercise clips.
///
/// The player keeps the source aspect ratio and is centred inside the square.
/// The leftover area stays transparent, so the page background shows through
/// instead of a baked-in black or white bar.
struct ExerciseMediaBox: View {
    let url: URL
    var cornerRadius: CGFloat = 20
    var isPlaying: Bool = true
    var onFailure: (() -> Void)? = nil

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SilentLoopingVideoPlayer(
                url: url,
                isPlaying: isPlaying && scenePhase == .active,
                onFailure: onFailure
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
