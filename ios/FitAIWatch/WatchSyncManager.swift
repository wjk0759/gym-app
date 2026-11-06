import Foundation
import WatchConnectivity
import FitAIWorkoutCore

/// Thin WatchConnectivity bridge. All workout decisions stay in
/// `WatchWorkoutStore`; this object only moves Codable envelopes.
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    weak var store: WatchWorkoutStore?
    private(set) var isReachable = false
    private(set) var lastSyncAt: Date?

    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private var isActivated = false

    func activate() {
        guard !isActivated, WCSession.isSupported() else { return }
        isActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(snapshot: WorkoutSessionSnapshot) {
        guard let session else { return }
        let envelope = WatchSessionEnvelope(
            sessionID: snapshot.sessionID,
            snapshot: snapshot
        )
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        let payload: [String: Any] = ["type": "session", "session": data]
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
        lastSyncAt = Date()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.receive(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.receive(userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.receive(message)
        }
        replyHandler(["ok": true])
    }

    private func receive(_ payload: [String: Any]) {
        guard let data = payload["bootstrap"] as? Data,
              let bootstrap = try? JSONDecoder().decode(WatchBootstrap.self, from: data) else {
            return
        }
        store?.applyBootstrap(bootstrap)
        lastSyncAt = Date()
    }
}
