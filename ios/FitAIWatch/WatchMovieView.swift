import AVFoundation
import AVKit
import Combine
import SwiftUI

/// watchOS only exposes video through AVKit's `VideoPlayer`; AVPlayerLayer and
/// AVPlayerItemVideoOutput are unavailable. The player is muted, has hit
/// testing disabled and loops the authored segment without any controls.
struct WatchMovieView: View {
    let url: URL?
    let isPlaying: Bool
    var loopStart: Double? = nil
    var loopEnd: Double? = nil

    @State private var player: AVPlayer?
    @State private var timeObserver: Any?

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
            tearDown()
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
            seekToLoopStart()
            player?.play()
        }
    }

    private func makePlayerIfNeeded(force: Bool = false) {
        guard force || player == nil else {
            if isPlaying { player?.play() }
            return
        }
        guard let url else {
            tearDown()
            return
        }
        tearDown()
        let next = AVPlayer(url: url)
        next.isMuted = true
        next.actionAtItemEnd = .none
        player = next
        observeLoop(on: next)
        seekToLoopStart()
        if isPlaying {
            next.play()
        }
    }

    private func observeLoop(on player: AVPlayer) {
        let end = loopEnd
        let start = loopStart ?? 0
        guard let end, end > start else { return }
        let observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite, seconds >= end - 0.08 {
                player.seek(
                    to: CMTime(seconds: start, preferredTimescale: 600),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }
        }
        timeObserver = observer
    }

    private func seekToLoopStart() {
        guard let player else { return }
        let start = loopStart ?? 0
        guard start > 0 else { return }
        player.seek(
            to: CMTime(seconds: start, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func tearDown() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        player?.pause()
        player = nil
    }
}
