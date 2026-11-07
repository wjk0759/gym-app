import Foundation
import FitAIWorkoutCore
import WatchConnectivity

/// WatchConnectivity bridge with a durable outbox.
///
/// A full snapshot is stored locally before it is sent, so finishing a workout
/// with the phone in a locker is safe. The phone acknowledges the revision
/// after persisting it; only then does the watch drop the outbox entry.
@MainActor
final class WatchSyncManager: NSObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    weak var store: WatchWorkoutStore?
    private(set) var isReachable = false
    private(set) var lastSyncAt: Date?
    private(set) var pendingCount = 0

    private var session: WCSession?
    private var isActivated = false
    private var lastBootstrapRequestAt: Date?
    private var outbox: [String: WatchSessionEnvelope] = [:]

    override init() {
        super.init()
        loadOutbox()
    }

    func activate() {
        guard !isActivated, WCSession.isSupported() else { return }
        isActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func send(snapshot: WorkoutSessionSnapshot) {
        let envelope = WatchSessionEnvelope(
            sessionID: snapshot.sessionID,
            snapshot: snapshot,
            userID: store?.bootstrap?.userID
                ?? WatchCredentialStore.shared.runtime?.userID
        )
        outbox[snapshot.sessionID.uuidString] = envelope
        if outbox.count > 20 {
            let overflow = outbox.count - 20
            let staleKeys = outbox.values
                .sorted(by: { $0.sentAt < $1.sentAt })
                .prefix(overflow)
                .map { $0.sessionID.uuidString }
            for key in staleKeys {
                outbox.removeValue(forKey: key)
            }
        }
        pendingCount = outbox.count
        persistOutbox()
        flush()
    }

    /// Ask the phone for a fresh plan, media list and watch credentials. Called
    /// on launch and when connectivity returns after a reinstall.
    func requestBootstrapFromPhone(
        force: Bool = false,
        includeDayID: Bool = true
    ) {
        guard let session else { return }
        let preservingSession = store?.hasUnfinishedWork == true
        let stalePlan = !preservingSession
            && (store?.bootstrap.map {
                !Calendar.current.isDateInToday($0.generatedAt)
            } ?? true)
        let last = lastBootstrapRequestAt
        if !force, let last, Date().timeIntervalSince(last) < 60 {
            return
        }
        if !force,
           !stalePlan,
           let last,
           Date().timeIntervalSince(last) < 2 * 60 * 60 {
            return
        }
        lastBootstrapRequestAt = Date()
        var payload: [String: Any] = [
            "type": "requestBootstrap",
            "force": force
        ]
        if includeDayID,
           !stalePlan,
           let bootstrap = store?.bootstrap,
           store?.snapshot.isFinished != true {
            payload["dayID"] = bootstrap.programDayID.uuidString
        }
        session.transferUserInfo(payload)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }

    private func flush() {
        guard let session, session.activationState == .activated else { return }
        let envelopes = outbox.values.sorted { $0.sentAt < $1.sentAt }
        for envelope in envelopes {
            guard let data = try? JSONEncoder().encode(envelope) else {
                continue
            }
            let payload: [String: Any] = ["type": "session", "session": data]
            session.transferUserInfo(payload)
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil)
            }
        }
        pendingCount = outbox.count
        if !envelopes.isEmpty {
            lastSyncAt = Date()
        }
    }

    private func receiveBootstrap(_ bootstrap: WatchBootstrap) {
        guard let store, store.applyBootstrap(bootstrap) else { return }
        let currentUser = bootstrap.userID
            ?? WatchCredentialStore.shared.runtime?.userID
        if let currentUser {
            outbox = outbox.filter {
                $0.value.userID == nil || $0.value.userID == currentUser
            }
            persistOutbox()
        }
        pendingCount = outbox.count
        lastSyncAt = Date()
    }

    private func applyAck(_ payload: [String: Any]) {
        guard let raw = payload["sessionID"] as? String,
              let revision = (payload["revision"] as? NSNumber)?.intValue
        else {
            return
        }
        if let envelope = outbox[raw],
           envelope.snapshot.revision <= revision {
            outbox.removeValue(forKey: raw)
            persistOutbox()
        }
        pendingCount = outbox.count
        lastSyncAt = Date()
    }

    private func handleLogout(_ payload: [String: Any]? = nil) {
        let logoutAt = payload?["at"] as? Date ?? Date()
        // A delayed logout can arrive after a newer login bootstrap. Do not
        // lock a watch that already proved a newer authenticated preload.
        if let latest = store?.bootstrap?.generatedAt, latest > logoutAt {
            return
        }
        UserDefaults.standard.set(
            logoutAt,
            forKey: WatchLockState.blockedBootstrapDateKey
        )
        UserDefaults.standard.set(true, forKey: "fitai_watch_force_lock")
        store?.lockForLogout()
        WatchCredentialStore.shared.clearAuth()
        outbox.removeAll()
        persistOutbox()
        pendingCount = 0
        lastBootstrapRequestAt = nil
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self, activationState == .activated else { return }
            self.isReachable = reachable
            self.flush()
            self.requestBootstrapFromPhone()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isReachable = reachable
            if reachable {
                self.flush()
                self.requestBootstrapFromPhone()
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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The system deletes this temporary file when the delegate returns, so
        // copy it synchronously before hopping to the main actor.
        let ext = file.fileURL.pathExtension
        let fallbackExt = (file.metadata?["kind"] as? String) == "poster"
            ? "jpg"
            : "mp4"
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext.isEmpty ? fallbackExt : ext)
        do {
            try? FileManager.default.removeItem(at: temporary)
            try FileManager.default.copyItem(at: file.fileURL, to: temporary)
        } catch {
            return
        }
        let metadata = file.metadata
        Task { @MainActor in
            _ = WatchMediaStore.shared.receive(
                fileURL: temporary,
                metadata: metadata
            )
            try? FileManager.default.removeItem(at: temporary)
        }
    }

    private func receive(_ payload: [String: Any]) {
        switch payload["type"] as? String {
        case "bootstrap":
            guard let data = payload["bootstrap"] as? Data,
                  let bootstrap = try? JSONDecoder().decode(
                      WatchBootstrap.self,
                      from: data
                  ) else {
                return
            }
            receiveBootstrap(bootstrap)
        case "command":
            guard let data = payload["command"] as? Data,
                  let command = try? JSONDecoder().decode(
                      WorkoutCommand.self,
                      from: data
                  ) else {
                return
            }
            store?.apply(command)
        case "requestState":
            if let store,
               !store.snapshot.exercises.isEmpty
                   || !store.snapshot.sets.isEmpty {
                store.publishSnapshot()
            } else if let session {
                let payload: [String: Any] = ["type": "emptyState"]
                session.transferUserInfo(payload)
                if session.isReachable {
                    session.sendMessage(payload, replyHandler: nil)
                }
            }
        case "ack":
            applyAck(payload)
        case "logout":
            handleLogout(payload)
        default:
            break
        }
    }

    // MARK: - Outbox persistence

    private struct StoredOutbox: Codable {
        var envelopes: [String: WatchSessionEnvelope]
    }

    private var outboxURL: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = root.appendingPathComponent(
            "FitAIWatch",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("outbox.json")
    }

    private func loadOutbox() {
        guard let data = try? Data(contentsOf: outboxURL),
              let stored = try? JSONDecoder().decode(
                  StoredOutbox.self,
                  from: data
              ) else {
            return
        }
        outbox = stored.envelopes
        pendingCount = outbox.count
    }

    private func persistOutbox() {
        let stored = StoredOutbox(envelopes: outbox)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: outboxURL, options: [.atomic])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = outboxURL
        try? url.setResourceValues(values)
    }
}
