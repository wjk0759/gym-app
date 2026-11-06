import AVFoundation
import AVKit
import Combine
import SwiftUI

/// watchOS only exposes video through AVKit's `VideoPlayer`; AVPlayerLayer and
/// AVPlayerItemVideoOutput are unavailable. The player is muted and has hit
/// testing disabled so the action page stays a passive demo surface.
struct WatchMovieView: View {
    let url: URL?
    let isPlaying: Bool

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .allowsHitTesting(false)
            } else {
                Color.black
            }
        }
        .onAppear {
            makePlayerIfNeeded()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: url) { _, _ in
            makePlayerIfNeeded(force: true)
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .AVPlayerItemDidPlayToEndTime
            )
        ) { notification in
            guard let item = notification.object as? AVPlayerItem,
                  item === player?.currentItem else { return }
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func makePlayerIfNeeded(force: Bool = false) {
        guard force || player == nil else {
            if isPlaying { player?.play() }
            return
        }
        guard let url else {
            player = nil
            return
        }
        let next = AVPlayer(url: url)
        next.isMuted = true
        next.actionAtItemEnd = .none
        player = next
        if isPlaying {
            next.play()
        }
    }
}
