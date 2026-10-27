import AVFoundation
import AVKit
import SwiftUI

/// Small looping player for short silent exercise demonstrations.
///
/// The video is expected to start and end in a neutral pose. AVPlayerLooper
/// keeps the clip cycling without a visible stop at the end of the asset.
struct LoopingVideoPlayer: View {
    let url: URL

    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear(perform: start)
            .onDisappear(perform: stop)
    }

    private func start() {
        guard player == nil else {
            player?.play()
            return
        }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        let loop = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        looper = loop
        queue.play()
    }

    private func stop() {
        player?.pause()
        looper?.disableLooping()
        player = nil
        looper = nil
    }
}
