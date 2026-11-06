import Foundation

/// A single exercise inside a workout session.
///
/// This is intentionally independent of the iOS app's SwiftUI/model layer so
/// the same value can be decoded on watchOS, sent over WatchConnectivity, and
/// persisted by either device.
public struct WorkoutExercise: Codable, Hashable, Identifiable, Sendable {
    public enum Target: Codable, Hashable, Sendable {
        case reps(min: Int, max: Int)
        case time(seconds: Int)

        public var isTimed: Bool {
            if case .time = self { return true }
            return false
        }
    }

    public var id: UUID
    public var slug: String
    public var name: String
    public var target: Target
    public var sets: Int
    public var weightKG: Double?
    public var restSeconds: Int
    public var isBodyweight: Bool
    public var isUnilateral: Bool
    public var equipment: String?

    public init(
        id: UUID = UUID(),
        slug: String,
        name: String,
        target: Target,
        sets: Int,
        weightKG: Double? = nil,
        restSeconds: Int = 60,
        isBodyweight: Bool = false,
        isUnilateral: Bool = false,
        equipment: String? = nil
    ) {
        self.id = id
        self.slug = slug
        self.name = name
        self.target = target
        self.sets = max(1, sets)
        self.weightKG = weightKG
        self.restSeconds = max(0, restSeconds)
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
        self.equipment = equipment
    }
}

/// One completed set. `exerciseID + setIndex` is the idempotency key used by
/// both the local engine and the server sync.
public struct WorkoutSetRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var exerciseID: UUID
    public var exerciseSlug: String
    public var setIndex: Int
    public var weightKG: Double
    public var reps: Int?
    public var seconds: Int?
    public var rpe: Double?
    public var completedAt: Date
    public var source: WorkoutCommandSource
    public var operationID: UUID

    public init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseSlug: String,
        setIndex: Int,
        weightKG: Double,
        reps: Int? = nil,
        seconds: Int? = nil,
        rpe: Double? = nil,
        completedAt: Date,
        source: WorkoutCommandSource,
        operationID: UUID
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseSlug = exerciseSlug
        self.setIndex = setIndex
        self.weightKG = max(0, weightKG)
        self.reps = reps
        self.seconds = seconds
        self.rpe = rpe
        self.completedAt = completedAt
        self.source = source
        self.operationID = operationID
    }
}

public enum WorkoutSessionStatus: String, Codable, Hashable, Sendable {
    case active
    case paused
    case finished
    case discarded
}

public enum WorkoutCommandSource: String, Codable, Hashable, Sendable {
    case phone
    case watch
    case server
}

/// Complete, serializable state for one workout.
///
/// This is the unit exchanged between iPhone and Apple Watch. It is also the
/// crash-recovery snapshot persisted by the watch app.
public struct WorkoutSessionSnapshot: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var sessionID: UUID
    public var programDayID: UUID
    public var dayTitle: String
    public var startedAt: Date
    public var finishedAt: Date?
    public var status: WorkoutSessionStatus
    public var exercises: [WorkoutExercise]
    public var sets: [WorkoutSetRecord]
    public var currentExerciseIndex: Int
    public var restEndsAt: Date?
    public var pausedRestRemaining: TimeInterval?
    public var isPaused: Bool
    public var revision: Int
    public var leaderDeviceID: UUID?
    public var appliedOperationIDs: [UUID]

    public init(
        sessionID: UUID = UUID(),
        programDayID: UUID,
        dayTitle: String,
        startedAt: Date,
        exercises: [WorkoutExercise],
        leaderDeviceID: UUID? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID
        self.programDayID = programDayID
        self.dayTitle = dayTitle
        self.startedAt = startedAt
        self.finishedAt = nil
        self.status = .active
        self.exercises = exercises
        self.sets = []
        self.currentExerciseIndex = 0
        self.restEndsAt = nil
        self.pausedRestRemaining = nil
        self.isPaused = false
        self.revision = 0
        self.leaderDeviceID = leaderDeviceID
        self.appliedOperationIDs = []
    }

    public var currentExercise: WorkoutExercise? {
        guard exercises.indices.contains(currentExerciseIndex) else { return nil }
        return exercises[currentExerciseIndex]
    }

    public var nextExercise: WorkoutExercise? {
        let next = currentExerciseIndex + 1
        guard exercises.indices.contains(next) else { return nil }
        return exercises[next]
    }

    public var plannedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    public var completedSetCount: Int {
        sets.count
    }

    public var progress: Double {
        guard plannedSetCount > 0 else { return 0 }
        return min(1, Double(completedSetCount) / Double(plannedSetCount))
    }

    public var isFinished: Bool {
        status == .finished || status == .discarded
    }

    public func completedSets(for exerciseID: UUID) -> Int {
        sets.reduce(0) { $0 + ($1.exerciseID == exerciseID ? 1 : 0) }
    }

    public func remainingSets(for exercise: WorkoutExercise) -> Int {
        max(0, exercise.sets - completedSets(for: exercise.id))
    }

    public func currentSetIndex(for exercise: WorkoutExercise) -> Int {
        min(exercise.sets, completedSets(for: exercise.id) + 1)
    }

    public func isExerciseComplete(_ exercise: WorkoutExercise) -> Bool {
        completedSets(for: exercise.id) >= exercise.sets
    }

    public func remainingRest(at date: Date) -> TimeInterval? {
        if isPaused {
            return pausedRestRemaining
        }
        guard let restEndsAt else { return nil }
        return max(0, restEndsAt.timeIntervalSince(date))
    }
}
