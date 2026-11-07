import Foundation
import Observation
import FitAIWorkoutCore

/// Watch-local source of truth for a preloaded workout. The store owns the
/// snapshot file and delegates all workout mutations to `WorkoutSessionEngine`.
@MainActor
@Observable
final class WatchWorkoutStore {
    private(set) var bootstrap: WatchBootstrap?
    private(set) var engine: WorkoutSessionEngine
    private(set) var isPro: Bool
    private(set) var hasStartedWorkout = false
    /// Set when the phone logs out. A cached session must not stay unlocked
    /// until a new Pro bootstrap arrives.
    private(set) var isAccountLocked = false
    private(set) var lastError: String?
    private let forceLockKey = "fitai_watch_force_lock"

    /// Wired to WatchConnectivity by the app shell. The store never imports
    /// the connectivity framework, keeping the workout state testable.
    var onSnapshotChange: ((WorkoutSessionSnapshot) -> Void)?

    var snapshot: WorkoutSessionSnapshot { engine.snapshot }

    /// A session that already has work logged may be finished even if the Pro
    /// entitlement expired or was refunded mid-workout. A merely cached plan
    /// with no completed set does not unlock the app.
    var hasUnfinishedWork: Bool {
        !snapshot.isFinished
            && !snapshot.exercises.isEmpty
            && (hasStartedWorkout || !snapshot.sets.isEmpty || snapshot.isPaused)
    }

    var canTrainNow: Bool {
        !isAccountLocked && (isPro || hasUnfinishedWork)
    }

    /// Only return files that were actually received by the watch. A remote
    /// URL would hang when the phone is in a locker, so the action page falls
    /// back to the poster or text instead.
    var currentMediaURL: URL? {
        guard let slug = snapshot.currentExercise?.slug else { return nil }
        return WatchMediaStore.shared.videoURL(slug: slug)
    }

    var currentPosterURL: URL? {
        guard let slug = snapshot.currentExercise?.slug else { return nil }
        return WatchMediaStore.shared.posterURL(slug: slug)
    }

    var currentLoopRange: (start: Double?, end: Double?)? {
        guard let slug = snapshot.currentExercise?.slug else { return nil }
        return WatchMediaStore.shared.loopRange(slug: slug)
    }

    var currentLoopStart: Double? {
        guard let range = currentLoopRange else { return nil }
        return range.start
    }

    var currentLoopEnd: Double? {
        guard let range = currentLoopRange else { return nil }
        return range.end
    }

    var voiceContext: String? {
        guard let exercise = snapshot.currentExercise else { return nil }
        let target: String
        switch exercise.target {
        case .reps(let min, let max):
            target = min == max ? "\(min) 次" : "\(min)–\(max) 次"
        case .time(let seconds):
            target = "\(seconds) 秒"
        }
        return "\(bootstrap?.dayTitle ?? "训练") · \(exercise.name) · "
            + "\(exercise.sets) 组 · \(target)"
    }

    init() {
        #if DEBUG
        let preview = WatchWorkoutPreview.bootstrap()
        self.bootstrap = preview
        self.engine = Self.makeEngine(from: preview)
        self.isPro = true
        #else
        self.bootstrap = nil
        self.engine = Self.emptyEngine()
        self.isPro = false
        #endif
        loadPersistedState()
        if UserDefaults.standard.bool(forKey: forceLockKey) {
            isAccountLocked = true
            isPro = false
        }
    }

    @discardableResult
    func applyBootstrap(_ payload: WatchBootstrap) -> Bool {
        // Bootstrap messages can be delivered out of order. Never let an older
        // payload replace a newer day, account or entitlement.
        if let current = bootstrap,
           payload.generatedAt < current.generatedAt {
            return false
        }
        let wasSameDay = bootstrap?.programDayID == payload.programDayID
        let accountChanged = payload.userID != nil
            && bootstrap?.userID != nil
            && payload.userID != bootstrap?.userID
        let preserveCurrentSession = !accountChanged
            && !wasSameDay
            && hasUnfinishedWork

        let access = accountChanged
            ? payload.access
            : mergedAccess(payload.access)
        WatchCredentialStore.shared.apply(
            apiBaseURL: payload.apiBaseURL,
            userID: payload.userID,
            auth: payload.auth
        )
        isPro = access.canTrain(at: Date())
        if isPro {
            isAccountLocked = false
            UserDefaults.standard.set(false, forKey: forceLockKey)
        }

        // A new day must not erase a watch-led session that has started, is
        // paused or has logged sets. Keep the old plan until that session is
        // finished or discarded; only entitlement/config is refreshed.
        if preserveCurrentSession {
            if var current = bootstrap {
                current.access = access
                current.auth = payload.auth ?? current.auth
                current.apiBaseURL = payload.apiBaseURL ?? current.apiBaseURL
                current.userID = payload.userID ?? current.userID
                bootstrap = current
            }
            persist()
            return true
        }

        var applied = payload
        applied.access = access
        bootstrap = applied
        WatchMediaStore.shared.prune(
            keeping: Set(payload.exercises.map(\.slug))
        )
        if accountChanged
            || !wasSameDay
            || engine.snapshot.isFinished {
            engine = Self.makeEngine(from: payload)
            hasStartedWorkout = false
        }
        persist()
        return true
    }

    /// The watch may have directly refreshed Pro more recently than the phone.
    /// Do not shorten its offline grace with an older phone timestamp, but do
    /// apply a server-returned free/refunded state immediately.
    private func mergedAccess(_ incoming: WatchAccess) -> WatchAccess {
        guard let current = bootstrap?.access,
              current.lastVerifiedAt > incoming.lastVerifiedAt else {
            return incoming
        }
        // A newer direct watch verification wins over an older phone cache,
        // whether it was Pro or free. A newer server response still applies
        // because it has the later timestamp.
        guard current.isPro == incoming.isPro else {
            return current
        }
        guard current.isPro else {
            return current
        }
        return WatchAccess(
            isPro: true,
            proExpiresAt: incoming.proExpiresAt ?? current.proExpiresAt,
            lastVerifiedAt: current.lastVerifiedAt
        )
    }

    func refreshEntitlement() {
        isPro = bootstrap?.access.canTrain(at: Date()) ?? false
    }

    /// Logging out on the phone must lock the watch even if an old Pro cache
    /// is still inside the offline grace window.
    func lockForLogout() {
        isPro = false
        isAccountLocked = true
        UserDefaults.standard.set(true, forKey: forceLockKey)
        if var payload = bootstrap {
            payload.access = WatchAccess(
                isPro: false,
                proExpiresAt: nil,
                lastVerifiedAt: Date()
            )
            payload.auth = nil
            bootstrap = payload
        }
        persist()
    }

    /// Refresh the server entitlement when the watch has its own login. The
    /// local three-day grace remains the offline fallback.
    func refreshEntitlementFromServer() async {
        guard WatchCredentialStore.shared.auth != nil else {
            refreshEntitlement()
            return
        }
        do {
            let access = try await WatchAPIClient.shared.refreshAccess()
            if var payload = bootstrap {
                payload.access = access
                bootstrap = payload
                isPro = access.canTrain(at: Date())
                if isPro {
                    isAccountLocked = false
                    UserDefaults.standard.set(false, forKey: forceLockKey)
                }
                persist()
            }
        } catch {
            lastError = (error as? WatchAPIError)?.message
                ?? "无法刷新 Pro 权益"
            refreshEntitlement()
        }
    }

    /// Re-send the current snapshot when the phone reconnects. Used to
    /// reconcile pause/finish state after the phone app was suspended.
    func publishSnapshot() {
        onSnapshotChange?(engine.snapshot)
    }

    @discardableResult
    func apply(_ command: WorkoutCommand) -> WorkoutTransition? {
        do {
            let startsSession = !hasStartedWorkout
                && command.startsWorkout
                && engine.snapshot.sets.isEmpty
                && !engine.snapshot.isFinished
            if startsSession {
                var snapshot = engine.snapshot
                snapshot.startedAt = command.at
                engine = WorkoutSessionEngine(snapshot: snapshot)
            }
            let transition = try engine.apply(command)
            if startsSession {
                hasStartedWorkout = true
            }
            lastError = nil
            persist()
            onSnapshotChange?(transition.snapshot)
            return transition
        } catch {
            lastError = String(describing: error)
            return nil
        }
    }

    private static func makeEngine(from bootstrap: WatchBootstrap) -> WorkoutSessionEngine {
        let snapshot = WorkoutSessionSnapshot(
            programDayID: bootstrap.programDayID,
            dayTitle: bootstrap.dayTitle,
            startedAt: Date(),
            exercises: bootstrap.exercises
        )
        return WorkoutSessionEngine(snapshot: snapshot)
    }

    private static func emptyEngine() -> WorkoutSessionEngine {
        WorkoutSessionEngine(
            snapshot: WorkoutSessionSnapshot(
                programDayID: UUID(),
                dayTitle: "训练",
                startedAt: Date(),
                exercises: []
            )
        )
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        var bootstrap: WatchBootstrap
        var snapshot: WorkoutSessionSnapshot
        var hasStarted: Bool?
        var isAccountLocked: Bool?
    }

    private var stateURL: URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent("watch-workout.json")
    }

    private func loadPersistedState() {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return
        }
        bootstrap = state.bootstrap
        engine = WorkoutSessionEngine(snapshot: state.snapshot)
        hasStartedWorkout = state.hasStarted
            ?? (!state.snapshot.sets.isEmpty || state.snapshot.isPaused)
        isAccountLocked = state.isAccountLocked ?? false
        isPro = state.bootstrap.access.canTrain(at: Date())
        // Keychain may hold a newer token pair than the cached bootstrap.
        WatchCredentialStore.shared.apply(
            apiBaseURL: state.bootstrap.apiBaseURL,
            userID: state.bootstrap.userID,
            auth: WatchCredentialStore.shared.auth ?? state.bootstrap.auth
        )
        WatchMediaStore.shared.prune(
            keeping: Set(state.bootstrap.exercises.map(\.slug))
        )
    }

    private func persist() {
        guard var bootstrap else { return }
        // Tokens live only in the Keychain. Keep the crash-recovery file free
        // of credentials in case the app container is inspected or backed up.
        bootstrap.auth = nil
        let state = PersistedState(
            bootstrap: bootstrap,
            snapshot: engine.snapshot,
            hasStarted: hasStartedWorkout,
            isAccountLocked: isAccountLocked
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: [.atomic])
    }
}

private extension WorkoutCommand {
    var startsWorkout: Bool {
        switch self {
        case .completeSet, .pause, .resume, .advanceExercise, .finish:
            return true
        case .undoLastSet, .skipRest:
            return false
        }
    }
}

/// Deterministic preview data for the watch shell while the real preload and
/// bootstrap flow is being wired. It is DEBUG-only at the call site.
enum WatchWorkoutPreview {
    static func bootstrap() -> WatchBootstrap {
        let exercises = [
            WorkoutExercise(
                slug: "bench_press",
                name: "哑铃卧推",
                target: .reps(min: 8, max: 10),
                sets: 3,
                weightKG: 60,
                restSeconds: 90,
                equipment: "哑铃"
            ),
            WorkoutExercise(
                slug: "plank",
                name: "平板支撑",
                target: .time(seconds: 30),
                sets: 3,
                weightKG: nil,
                restSeconds: 45,
                isBodyweight: true,
                equipment: "自重"
            )
        ]
        return WatchBootstrap(
            serverTime: Date(),
            programDayID: UUID(),
            dayTitle: "推",
            exercises: exercises,
            media: [],
            access: WatchAccess(
                isPro: true,
                proExpiresAt: Date().addingTimeInterval(30 * 24 * 60 * 60),
                lastVerifiedAt: Date()
            )
        )
    }
}
