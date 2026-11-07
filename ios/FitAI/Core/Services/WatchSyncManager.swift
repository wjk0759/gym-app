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
    private(set) var watchSessionDayID: UUID?
    private(set) var isWatchSessionPaused = false
    private var watchSessionID: UUID?

    /// Set by `WorkoutSessionView` while the matching day is on screen. When
    /// set, snapshots update the UI directly; otherwise they go to the durable
    /// inbox and are ingested by the app shell.
    var activeWorkoutDayID: UUID?
    var onSnapshotReceived: ((WatchSessionEnvelope) -> Void)?

    private var session: WCSession?
    private var isActivated = false
    private var isPreparingBootstrap = false
    private var authGeneration = 0
    private var pendingMedia: [WatchMediaAsset] = []
    private let mediaPreloader = WatchMediaPreloader()

    private let watchDeviceKey = "fitai_watch_session_device_id"
    private let lastBootstrapDayKey = "fitai_watch_last_bootstrap_day"
    private let lastBootstrapAtKey = "fitai_watch_last_bootstrap_at"
    private let appliedRevisionsKey = "fitai_watch_applied_revisions"
    private let activeWatchSessionKey = "fitai_watch_active_session"

    private var watchDeviceID: String {
        if let value = UserDefaults.standard.string(forKey: watchDeviceKey),
           !value.isEmpty {
            return value
        }
        let value = "watch-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: watchDeviceKey)
        return value
    }

    override init() {
        super.init()
        restoreActiveWatchSession()
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
        verifiedAt: Date?,
        force: Bool = false
    ) async {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              !isPreparingBootstrap else { return }
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
        let generation = authGeneration
        let startingUserID = AuthTokenStore.shared.userID

        var remote: RemoteWatchBootstrap?
        var auth: WatchAuth?
        var freshAccess: AccessSnapshot?
        var freshVerifiedAt: Date?
        var bootstrapForbidden = false
        if AuthTokenStore.shared.accessToken != nil {
            do {
                remote = try await APIClient.shared.fetchWatchBootstrap(
                    dayID: day.id
                )
            } catch let error as APIError where error.statusCode == 403 {
                // A 403 from the Pro-gated bootstrap is itself an authoritative
                // free response, even if the follow-up access call fails.
                bootstrapForbidden = true
                freshVerifiedAt = Date()
            } catch {
                // Network/5xx: keep the watch's cached plan and grace period.
            }
            if remote == nil,
               let fresh = try? await APIClient.shared.fetchAccess() {
                // The bootstrap 403s for a free/refunded account. Never fall
                // back to a stale local Pro snapshot after a server rejection.
                freshAccess = fresh
                freshVerifiedAt = Date()
            }
            if let credentials = try? await APIClient.shared.createWatchSession(
                deviceID: watchDeviceID
            ) {
                auth = credentials.auth()
            }
        }

        // The user may log out or switch accounts while the network requests
        // are in flight. Never let that stale task unlock the watch.
        guard generation == authGeneration,
              AuthTokenStore.shared.userID == startingUserID else {
            return
        }

        // With no verified snapshot and no explicit server rejection, sending
        // a free payload would overwrite the watch's valid offline grace after
        // a cold launch without network. Keep the cached watch state instead.
        if remote == nil,
           freshAccess == nil,
           access == nil,
           !bootstrapForbidden,
           AuthTokenStore.shared.accessToken != nil {
            return
        }

        let media = remote?.media.map {
            $0.asset(resolvingAgainst: AppConfig.apiBaseURL)
        } ?? []
        let snapshot: AccessSnapshot? = bootstrapForbidden && freshAccess == nil
            ? nil
            : (remote?.access ?? freshAccess ?? access)
        let verification = remote?.serverTime
            ?? freshVerifiedAt
            ?? verifiedAt
            ?? (access != nil ? Date() : Date.distantPast)
        let exercises = remote?.programDay.watchExercises
            ?? day.exercises.map { WorkoutExercise(planExercise: $0) }
        let payload = WatchBootstrap(
            serverTime: verification,
            programDayID: remote?.programDay.id ?? day.id,
            dayTitle: remote?.programDay.title ?? day.title,
            exercises: exercises,
            media: media,
            access: WatchAccess(
                isPro: snapshot?.isPro == true,
                proExpiresAt: snapshot?.proExpiresAt,
                lastVerifiedAt: verification
            ),
            userID: AuthTokenStore.shared.userID,
            apiBaseURL: AppConfig.apiBaseURLString,
            auth: auth
        )
        guard sendBootstrap(payload) else { return }
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

    @discardableResult
    private func sendBootstrap(_ payload: WatchBootstrap) -> Bool {
        guard let session,
              session.activationState == .activated,
              let data = try? JSONEncoder().encode(payload) else {
            return false
        }
        let message: [String: Any] = ["type": "bootstrap", "bootstrap": data]
        try? session.updateApplicationContext(message)
        session.transferUserInfo(message)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        }
        lastSyncAt = Date()
        return true
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
        markApplied(sessionID: sessionID, revision: revision)
        sendAck(sessionID: sessionID, revision: revision)
    }

    func clearInbox() {
        try? FileManager.default.removeItem(at: inboxDirectory)
        UserDefaults.standard.removeObject(forKey: appliedRevisionsKey)
    }

    private func appliedRevision(sessionID: UUID) -> Int {
        appliedRevisions()[sessionID.uuidString] ?? 0
    }

    private func appliedRevisions() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: appliedRevisionsKey),
              let values = try? JSONDecoder().decode(
                  [String: Int].self,
                  from: data
              ) else {
            return [:]
        }
        return values
    }

    private func markApplied(sessionID: UUID, revision: Int) {
        var values = appliedRevisions()
        values[sessionID.uuidString] = max(
            values[sessionID.uuidString] ?? 0,
            revision
        )
        if values.count > 100 {
            let overflow = values.count - 100
            for key in values.keys.sorted().prefix(overflow) {
                values.removeValue(forKey: key)
            }
        }
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: appliedRevisionsKey)
    }

    private func storeInbox(_ envelope: WatchSessionEnvelope) -> Bool {
        let url = inboxDirectory
            .appendingPathComponent(envelope.sessionID.uuidString)
            .appendingPathExtension("json")
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONDecoder().decode(
               WatchSessionEnvelope.self,
               from: data
           ),
           existing.snapshot.revision >= envelope.snapshot.revision {
            return false
        }
        guard let data = try? JSONEncoder().encode(envelope) else {
            return false
        }
        do {
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
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

    private func requestWatchState() {
        guard let session, session.activationState == .activated else {
            return
        }
        let payload: [String: Any] = ["type": "requestState"]
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    /// A watch-led session makes the phone a controller/mirror until the watch
    /// finishes it or the 24-hour safety window expires.
    func hasActiveWatchSession(for dayID: UUID) -> Bool {
        guard let saved = loadActiveWatchSession() else {
            watchSessionDayID = nil
            watchSessionID = nil
            return false
        }
        if Date().timeIntervalSince(saved.savedAt) > 24 * 60 * 60 {
            clearActiveWatchSession()
            return false
        }
        isWatchSessionPaused = saved.isPaused ?? false
        return saved.dayID == dayID
    }

    private struct ActiveWatchSession: Codable {
        var sessionID: UUID
        var dayID: UUID
        var userID: String?
        var savedAt: Date
        var isPaused: Bool?
    }

    private func saveActiveWatchSession(
        sessionID: UUID,
        dayID: UUID,
        isPaused: Bool
    ) {
        let value = ActiveWatchSession(
            sessionID: sessionID,
            dayID: dayID,
            userID: AuthTokenStore.shared.userID,
            savedAt: Date(),
            isPaused: isPaused
        )
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: activeWatchSessionKey)
        }
    }

    private func loadActiveWatchSession() -> ActiveWatchSession? {
        guard let data = UserDefaults.standard.data(
            forKey: activeWatchSessionKey
        ), let value = try? JSONDecoder().decode(
            ActiveWatchSession.self,
            from: data
        ) else {
            return nil
        }
        if let userID = value.userID,
           userID != AuthTokenStore.shared.userID {
            clearActiveWatchSession()
            return nil
        }
        return value
    }

    private func clearActiveWatchSession() {
        UserDefaults.standard.removeObject(forKey: activeWatchSessionKey)
        watchSessionDayID = nil
        watchSessionID = nil
        isWatchSessionPaused = false
    }

    private func restoreActiveWatchSession() {
        guard let saved = loadActiveWatchSession(),
              Date().timeIntervalSince(saved.savedAt) < 24 * 60 * 60 else {
            return
        }
        watchSessionID = saved.sessionID
        watchSessionDayID = saved.dayID
        isWatchSessionPaused = saved.isPaused ?? false
    }

    /// Phone commands are only accepted while the watch is reachable. Offline
    /// the phone is a read-only mirror; it must not create a divergent session.
    @discardableResult
    func send(command: WorkoutCommand) -> Bool {
        guard let session, session.isReachable,
              let data = try? JSONEncoder().encode(command) else {
            return false
        }
        let payload: [String: Any] = ["type": "command", "command": data]
        session.sendMessage(
            payload,
            replyHandler: nil
        ) { _ in
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .fitaiWatchCommandFailed,
                    object: nil
                )
            }
        }
        return true
    }

    /// Stop the watch from using a logged-out account. Cached plan/media stay
    /// on the watch so an offline workout can still be completed; auth, inbox
    /// and active-session ownership are cleared.
    func resetForLogout() {
        authGeneration += 1
        clearInbox()
        activeWorkoutDayID = nil
        clearActiveWatchSession()
        pendingMedia = []
        UserDefaults.standard.removeObject(forKey: lastBootstrapDayKey)
        UserDefaults.standard.removeObject(forKey: lastBootstrapAtKey)
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
            if installed {
                NotificationCenter.default.post(
                    name: .fitaiWatchBecameAvailable,
                    object: nil
                )
                if !self.pendingMedia.isEmpty {
                    await self.mediaPreloader.preload(
                        media: self.pendingMedia,
                        session: session
                    )
                }
                if self.watchSessionDayID != nil {
                    self.requestWatchState()
                }
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let installed = session.isWatchAppInstalled
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isWatchAppInstalled = installed
            self?.isReachable = reachable
            if installed {
                NotificationCenter.default.post(
                    name: .fitaiWatchBecameAvailable,
                    object: nil
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
            guard let self else { return }
            self.isReachable = reachable
            if reachable, self.watchSessionDayID != nil {
                self.requestWatchState()
            }
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
            let dayID = (payload["dayID"] as? String)
                .flatMap { UUID(uuidString: $0) }
            let force = (payload["force"] as? NSNumber)?.boolValue
                ?? (payload["force"] as? Bool)
                ?? false
            NotificationCenter.default.post(
                name: .fitaiWatchBootstrapRequested,
                object: dayID,
                userInfo: ["force": force]
            )
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
            if envelope.snapshot.revision
                <= appliedRevision(sessionID: envelope.sessionID) {
                sendAck(
                    sessionID: envelope.sessionID,
                    revision: envelope.snapshot.revision
                )
                return
            }
            guard storeInbox(envelope) else {
                return
            }
            sendAck(
                sessionID: envelope.sessionID,
                revision: envelope.snapshot.revision
            )
            if envelope.snapshot.isFinished {
                if watchSessionID == nil
                    || watchSessionID == envelope.sessionID {
                    clearActiveWatchSession()
                }
            } else {
                watchSessionID = envelope.sessionID
                watchSessionDayID = envelope.snapshot.programDayID
                isWatchSessionPaused = envelope.snapshot.isPaused
                saveActiveWatchSession(
                    sessionID: envelope.sessionID,
                    dayID: envelope.snapshot.programDayID,
                    isPaused: envelope.snapshot.isPaused
                )
            }
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
    static let fitaiWatchBecameAvailable = Notification.Name(
        "fitai.watch.became.available"
    )
    static let fitaiWatchCommandFailed = Notification.Name(
        "fitai.watch.command.failed"
    )
}
