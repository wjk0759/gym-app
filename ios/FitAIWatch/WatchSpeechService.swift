import AVFoundation
import Combine
import Foundation

enum WatchSpeechMode: String, CaseIterable, Identifiable {
    case silent
    case headphones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .silent: return "静音（点按朗读）"
        case .headphones: return "仅耳机自动朗读"
        }
    }

    var shortTitle: String {
        switch self {
        case .silent: return "静音"
        case .headphones: return "耳机自动"
        }
    }
}

/// On-device text-to-speech. Voice is silent by default; the speaker button
/// always works, and the headphone mode only auto-reads when a headset is
/// connected so the gym does not broadcast the coach out loud.
@MainActor
final class WatchSpeechService: NSObject, ObservableObject,
    AVSpeechSynthesizerDelegate {
    static let shared = WatchSpeechService()

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    var hasHeadphones: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { output in
            output.portType == .headphones
                || output.portType == .bluetoothA2DP
                || output.portType == .bluetoothHFP
                || output.portType == .bluetoothLE
        }
    }

    func shouldAutoSpeak(mode: WatchSpeechMode) -> Bool {
        mode == .headphones && hasHeadphones
    }

    func speak(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        stop()
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers]
        )
        try? audioSession.setActive(true)

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishSpeaking()
        }
    }

    private func finishSpeaking() {
        isSpeaking = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
        )
    }
}
