import Foundation
import WatchConnectivity
import FitAIWorkoutCore

/// iPhone side of the watch preload/sync bridge. The payload is a versioned
/// Codable snapshot; no workout rules are duplicated here.
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    private(set) var isReachable = false
    private(set) var isWatchAppInstalled = false
    private(set) var lastSyncAt: Date?
    private(set) var lastReceivedEnvelope: WatchSessionEnvelope?

    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private var isActivated = false

    var onSnapshotReceived: ((WatchSessionEnvelope) -> Void)?

    func activate() {
        guard !isActivated, WCSession.isSupported() else { return }
        isActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func sendBootstrap(
        day: PlanDay,
        access: AccessSnapshot?,
        media: [WatchMediaAsset] = []
    ) {
        guard let session else { return }
        let payload = WatchBootstrap(
            serverTime: Date(),
            programDayID: day.id,
            dayTitle: day.title,
            exercises: day.exercises.map { WorkoutExercise(planExercise: $0) },
            media: media,
            access: WatchAccess(
                isPro: access?.isPro == true,
                proExpiresAt: access?.proExpiresAt,
                lastVerifiedAt: Date()
            )
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let message: [String: Any] = ["type": "bootstrap", "bootstrap": data]
        try? session.updateApplicationContext(message)
        session.transferUserInfo(message)
        lastSyncAt = Date()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let installed = session.isWatchAppInstalled
        Task { @MainActor [weak self] in
            self?.isReachable = reachable
            self?.isWatchAppInstalled = installed
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
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
        guard let data = payload["session"] as? Data,
              let envelope = try? JSONDecoder().decode(
                WatchSessionEnvelope.self,
                from: data
              ) else {
            return
        }
        lastReceivedEnvelope = envelope
        lastSyncAt = Date()
        onSnapshotReceived?(envelope)
        NotificationCenter.default.post(
            name: .fitaiWatchSessionUpdated,
            object: envelope
        )
    }
}

extension Notification.Name {
    static let fitaiWatchSessionUpdated = Notification.Name(
        "fitai.watch.session.updated"
    )
}
