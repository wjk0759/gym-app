import Foundation
import FitAIWorkoutCore
import WatchConnectivity

/// iPhone side of the watch preload/sync bridge.
///
/// The phone is the only device that talks to the server. It mints a dedicated
/// watch login session, resolves the server-side exercise list and media,
/// queues media files, and persists incoming watch snapshots before
/// acknowledging them. If the phone is offline, the normal workout sync queue
/// uploads the finished session later.
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    private(set) var isReachable = false
    private(set) var isWatchAppInstalled = false
    private(set) var lastSyncAt: Date?
    private(set) var lastReceivedEnvelope: WatchSessionEnvelope?

    /// Set by `WorkoutSessionView` while the matching day is on screen. When
    /// set, snapshots update the UI directly; otherwise they go to the durable
    /// inbox and are ingested by the app shell.
    var activeWorkoutDayID: UUID?
    var onSnapshotReceived: ((WatchSessionEnvelope) -> Void)?

    private var session: WCSession?
    private var isActivated = false
    private var isPreparingBootstrap = false
    private var pendingMedia: [WatchMediaAsset] = []
    private let mediaPreloader = WatchMediaPreloader()

    private let watchDeviceKey = "fitai_watch_session_device_id"
    private let lastBootstrapDayKey = "fitai_watch_last_bootstrap_day"
    private let lastBootstrapAtKey = "fitai_watch_last_bootstrap_at"

    private var watchDeviceID: String {
        if let value = UserDefaults.standard.string(forKey: watchDeviceKey),
           !value.isEmpty {
            return value
        }
        let value = "watch-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: watchDeviceKey)
        return value
    }

    func activate() {
        guard !isActivated, WCSession.isSupported() else { return }
        isActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Fetch the authoritative plan/media, mint a watch session and push the
    /// payload before the phone is left behind. Local plan data is the fallback
    /// when the phone is offline; media is optional.
    func prepareAndSendBootstrap(
        day: PlanDay,
        access: AccessSnapshot?,
        force: Bool = false
    ) async {
        guard let session, !isPreparingBootstrap else { return }
        if !force,
           UserDefaults.standard.string(forKey: lastBootstrapDayKey)
               == day.id.uuidString,
           let last = UserDefaults.standard.object(
               forKey: lastBootstrapAtKey
           ) as? Date,
           Date().timeIntervalSince(last) < 6 * 60 * 60 {
            return
        }
        isPreparingBootstrap = true
        defer { isPreparingBootstrap = false }

        var remote: RemoteWatchBootstrap?
        var auth: WatchAuth?
        if AuthTokenStore.shared.accessToken != nil {
            remote = try? await APIClient.shared.fetchWatchBootstrap(dayID: day.id)
            if let credentials = try? await APIClient.shared.createWatchSession(
                deviceID: watchDeviceID
            ) {
                auth = credentials.auth()
            }
        }

        let media = remote?.media.map {
            $0.asset(resolvingAgainst: AppConfig.apiBaseURL)
        } ?? []
        let snapshot = remote?.access ?? access
        let verifiedAt = remote?.serverTime ?? Date()
        let exercises = remote?.programDay.watchExercises
            ?? day.exercises.map { WorkoutExercise(planExercise: $0) }
        let payload = WatchBootstrap(
            serverTime: verifiedAt,
            programDayID: remote?.programDay.id ?? day.id,
            dayTitle: remote?.programDay.title ?? day.title,
            exercises: exercises,
            media: media,
            access: WatchAccess(
                isPro: snapshot?.isPro == true,
                proExpiresAt: snapshot?.proExpiresAt,
                lastVerifiedAt: verifiedAt
            ),
            userID: AuthTokenStore.shared.userID,
            apiBaseURL: AppConfig.apiBaseURLString,
            auth: auth
        )
        sendBootstrap(payload)
        pendingMedia = media
        UserDefaults.standard.set(
            day.id.uuidString,
            forKey: lastBootstrapDayKey
        )
        UserDefaults.standard.set(Date(), forKey: lastBootstrapAtKey)
        if !media.isEmpty, session.isWatchAppInstalled {
            await mediaPreloader.preload(media: media, session: session)
        }
    }

    private func sendBootstrap(_ payload: WatchBootstrap) {
        guard let session,
              let data = try? JSONEncoder().encode(payload) else { return }
        let message: [String: Any] = ["type": "bootstrap", "bootstrap": data]
        try? session.updateApplicationContext(message)
        session.transferUserInfo(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        }
        lastSyncAt = Date()
    }

    // MARK: - Durable inbox

    private var inboxDirectory: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = root.appendingPathComponent(
            "FitAIWatchInbox",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    func pendingEnvelopes(for dayID: UUID? = nil) -> [WatchSessionEnvelope] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: inboxDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> WatchSessionEnvelope? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(
                    WatchSessionEnvelope.self,
                    from: data
                )
            }
            .filter { envelope in
                guard let dayID else { return true }
                return envelope.snapshot.programDayID == dayID
            }
            .sorted { $0.sentAt < $1.sentAt }
    }

    /// Remove an envelope only after the UI or app shell consumed it. The
    /// watch gets an acknowledgement so it can clear its own outbox.
    func acknowledgeInbox(sessionID: UUID, revision: Int) {
        let url = inboxDirectory
            .appendingPathComponent(sessionID.uuidString)
            .appendingPathExtension("json")
        if let data = try? Data(contentsOf: url),
           let envelope = try? JSONDecoder().decode(
               WatchSessionEnvelope.self,
               from: data
           ),
           envelope.snapshot.revision > revision {
            return
        }
        try? FileManager.default.removeItem(at: url)
        sendAck(sessionID: sessionID, revision: revision)
    }

    func clearInbox() {
        try? FileManager.default.removeItem(at: inboxDirectory)
    }

    private func storeInbox(_ envelope: WatchSessionEnvelope) {
        let url = inboxDirectory
            .appendingPathComponent(envelope.sessionID.uuidString)
            .appendingPathExtension("json")
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder().decode(
               WatchSessionEnvelope.self,
               from: data
           ),
           existing.snapshot.revision > envelope.snapshot.revision {
            return
        }
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: url, options: [.atomic])
    }

    private func sendAck(sessionID: UUID, revision: Int) {
        guard let session else { return }
        let payload: [String: Any] = [
            "type": "ack",
            "sessionID": sessionID.uuidString,
            "revision": revision
        ]
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    /// Stop the watch from using a logged-out account. Cached plan files stay
    /// on the watch so an offline workout can still be completed; only auth
    /// and pending sync state are cleared.
    func resetForLogout() {
        clearInbox()
        activeWorkoutDayID = nil
        guard let session else { return }
        let payload: [String: Any] = ["type": "logout"]
        try? session.updateApplicationContext(payload)
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        let installed = session.isWatchAppInstalled
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReachable = reachable
            self.isWatchAppInstalled = installed
            if installed, !self.pendingMedia.isEmpty {
                await self.mediaPreloader.preload(
                    media: self.pendingMedia,
                    session: session
                )
            }
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
        switch payload["type"] as? String {
        case "requestBootstrap":
            if let raw = payload["dayID"] as? String,
               let dayID = UUID(uuidString: raw) {
                NotificationCenter.default.post(
                    name: .fitaiWatchBootstrapRequested,
                    object: dayID
                )
            }
        case "session":
            guard let data = payload["session"] as? Data,
                  let envelope = try? JSONDecoder().decode(
                      WatchSessionEnvelope.self,
                      from: data
                  ) else {
                return
            }
            if let userID = envelope.userID,
               userID != AuthTokenStore.shared.userID {
                return
            }
            lastReceivedEnvelope = envelope
            lastSyncAt = Date()
            storeInbox(envelope)
            sendAck(
                sessionID: envelope.sessionID,
                revision: envelope.snapshot.revision
            )
            onSnapshotReceived?(envelope)
            let name: Notification.Name =
                activeWorkoutDayID == envelope.snapshot.programDayID
                ? .fitaiWatchSessionUpdated
                : .fitaiWatchSessionPending
            NotificationCenter.default.post(name: name, object: envelope)
        default:
            break
        }
    }
}

extension Notification.Name {
    static let fitaiWatchSessionUpdated = Notification.Name(
        "fitai.watch.session.updated"
    )
    static let fitaiWatchSessionPending = Notification.Name(
        "fitai.watch.session.pending"
    )
    static let fitaiWatchBootstrapRequested = Notification.Name(
        "fitai.watch.bootstrap.requested"
    )
}
