#if DEBUG
import Foundation
import QuartzCore
import UIKit

@MainActor
final class FrameHitchMonitor {
    static let shared = FrameHitchMonitor()

    private var link: CADisplayLink?
    private var flushTimer: Timer?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastMark = "none"
    private var buffer: [String] = []

    private let hitchThresholdMS: Double = 34
    private let writeQueue = DispatchQueue(label: "com.fitai.frame-hitches", qos: .utility)

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    func startIfRequested() {
        guard ProcessInfo.processInfo.environment["FITAI_QA_FRAME_LOG"] == "1", link == nil else {
            return
        }
        resetLog()

        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link

        flushTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flushToDisk()
            }
        }
    }

    func mark(_ name: String) {
        guard link != nil else { return }
        lastMark = name
        buffer.append("MARK \(name) \(timestamp())\n")
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard lastTimestamp > 0 else { return }

        let deltaMS = (link.timestamp - lastTimestamp) * 1000
        guard deltaMS > hitchThresholdMS else { return }
        buffer.append("HITCH \(timestamp()) \(Int(deltaMS))ms after=\(lastMark)\n")
    }

    private func flushToDisk() {
        guard !buffer.isEmpty, let url = logURL() else { return }
        let text = buffer.joined()
        buffer.removeAll(keepingCapacity: true)
        let data = Data(text.utf8)
        writeQueue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    private func timestamp() -> String {
        Self.formatter.string(from: Date())
    }

    private func logURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("frame-hitches.log")
    }

    private func resetLog() {
        guard let url = logURL() else { return }
        try? Data().write(to: url)
    }
}
#endif
