import Foundation

struct TelemetryEvent: Codable, Hashable {
    let name: String
    let properties: [String: String]
}

struct TelemetryEventBatch: Encodable {
    let events: [TelemetryEvent]
}

/// Small first-party funnel queue.
///
/// Events are persisted before upload, sent in batches, and retried on the
/// next foreground or app launch. No chat or health content is included.
@MainActor
final class Telemetry {
    static let shared = Telemetry()

    private let defaultsKey = "fitai.telemetry.pending"
    private let maxQueueSize = 100
    private var queue: [TelemetryEvent] = []
    private var isFlushing = false

    private init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let items = try? JSONDecoder().decode(
                  [TelemetryEvent].self,
                  from: data
              ) else { return }
        queue = items
    }

    func track(_ name: String, properties: [String: String] = [:]) {
        guard !name.isEmpty else { return }
        queue.append(TelemetryEvent(name: name, properties: properties))
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
        }
        persist()
        if queue.count >= 10 {
            flush()
        }
    }

    func flush() {
        guard !queue.isEmpty,
              !isFlushing,
              AuthTokenStore.shared.accessToken != nil else { return }
        isFlushing = true
        let batch = Array(queue.prefix(20))
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await APIClient.shared.sendClientEvents(batch)
                self.queue.removeFirst(min(batch.count, self.queue.count))
                self.persist()
                self.isFlushing = false
                if !self.queue.isEmpty {
                    self.flush()
                }
            } catch {
                self.isFlushing = false
            }
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
