import AVFoundation
import Combine
import SwiftUI
import UIKit

/// Silent, control-free loop for exercise demonstrations.
///
/// The player uses `AVPlayerLayer` rather than SwiftUI's `VideoPlayer` so the
/// workout screen never shows built-in playback controls.
struct SilentLoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    var isPlaying: Bool = true
    var onFailure: (() -> Void)?

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        let view = LoopingPlayerUIView()
        view.onFailure = onFailure
        view.configure(url: url, isPlaying: isPlaying)
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.onFailure = onFailure
        uiView.configure(url: url, isPlaying: isPlaying)
    }

    static func dismantleUIView(
        _ uiView: LoopingPlayerUIView,
        coordinator: ()
    ) {
        uiView.tearDown()
    }
}

final class LoopingPlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var onFailure: (() -> Void)?

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var statusCancellable: AnyCancellable?
    private var currentURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isOpaque = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        playerLayer.backgroundColor = UIColor.clear.cgColor
        playerLayer.videoGravity = .resizeAspect
    }

    func configure(url: URL, isPlaying: Bool) {
        if currentURL != url {
            buildPlayer(url: url)
        }
        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func tearDown() {
        statusCancellable?.cancel()
        statusCancellable = nil
        player?.pause()
        looper?.disableLooping()
        playerLayer.player = nil
        player = nil
        looper = nil
        currentURL = nil
    }

    private func buildPlayer(url: URL) {
        tearDown()
        currentURL = url

        // The loop is muted; ambient + mixWithOthers keeps the user's music
        // playing and never takes over the audio route.
        try? AVAudioSession.sharedInstance().setCategory(
            .ambient,
            mode: .moviePlayback,
            options: [.mixWithOthers]
        )

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.actionAtItemEnd = .none
        let loop = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        looper = loop
        playerLayer.player = queue

        statusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard status == .failed else { return }
                self?.player?.pause()
                self?.onFailure?()
            }
    }
}
