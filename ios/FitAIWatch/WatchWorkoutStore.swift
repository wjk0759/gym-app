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
    private(set) var lastError: String?

    /// Wired to WatchConnectivity by the app shell. The store never imports
    /// the connectivity framework, keeping the workout state testable.
    var onSnapshotChange: ((WorkoutSessionSnapshot) -> Void)?

    var snapshot: WorkoutSessionSnapshot { engine.snapshot }

    var currentMediaURL: URL? {
        guard let slug = snapshot.currentExercise?.slug else { return nil }
        return bootstrap?.media.first(where: { $0.exerciseSlug == slug })?.watchURL
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
    }

    func applyBootstrap(_ payload: WatchBootstrap) {
        let wasSameDay = bootstrap?.programDayID == payload.programDayID
        bootstrap = payload
        isPro = payload.access.canTrain(at: Date())
        if !wasSameDay || engine.snapshot.isFinished {
            engine = Self.makeEngine(from: payload)
        }
        persist()
    }

    func refreshEntitlement() {
        isPro = bootstrap?.access.canTrain(at: Date()) ?? false
    }

    @discardableResult
    func apply(_ command: WorkoutCommand) -> WorkoutTransition? {
        do {
            let transition = try engine.apply(command)
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
        isPro = state.bootstrap.access.canTrain(at: Date())
    }

    private func persist() {
        guard let bootstrap else { return }
        let state = PersistedState(bootstrap: bootstrap, snapshot: engine.snapshot)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: [.atomic])
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
