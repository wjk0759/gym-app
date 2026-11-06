import SwiftUI
import WatchKit

/// Thin SwiftUI bridge for the watchOS inline movie player. The coordinator
/// prevents every SwiftUI update from restarting the loop or resetting playback.
struct WatchMovieView: WKInterfaceObjectRepresentable {
    let url: URL?
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeWKInterfaceObject(context: Context) -> WKInterfaceInlineMovie {
        WKInterfaceInlineMovie()
    }

    func updateWKInterfaceObject(
        _ movie: WKInterfaceInlineMovie,
        context: Context
    ) {
        guard let url else {
            movie.pause()
            context.coordinator.currentURL = nil
            context.coordinator.isPlaying = false
            return
        }

        if context.coordinator.currentURL != url {
            context.coordinator.currentURL = url
            movie.setMovieURL(url)
            movie.setLoops(true)
            movie.setAutoplays(true)
            movie.playFromBeginning()
            context.coordinator.isPlaying = true
        }

        guard context.coordinator.isPlaying != isPlaying else { return }
        context.coordinator.isPlaying = isPlaying
        if isPlaying {
            movie.play()
        } else {
            movie.pause()
        }
    }

    static func dismantleWKInterfaceObject(
        _ movie: WKInterfaceInlineMovie,
        coordinator: Coordinator
    ) {
        movie.pause()
    }

    final class Coordinator {
        var currentURL: URL?
        var isPlaying = false
    }
}
