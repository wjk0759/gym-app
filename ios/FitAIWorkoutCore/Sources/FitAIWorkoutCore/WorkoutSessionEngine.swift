import Foundation

/// Commands are the only way to mutate a session.
///
/// Every command carries an `operationID`, which makes retries safe when the
/// phone, watch and server reconcile after being offline.
public enum WorkoutCommand: Codable, Hashable, Sendable {
    case completeSet(CompleteSet)
    case undoLastSet(UndoLastSet)
    case pause(PauseSession)
    case resume(ResumeSession)
    case skipRest(SkipRest)
    case advanceExercise(AdvanceExercise)
    case finish(FinishSession)

    public struct CompleteSet: Codable, Hashable, Sendable {
        public var exerciseID: UUID
        public var setIndex: Int
        public var weightKG: Double
        public var reps: Int?
        public var seconds: Int?
        public var rpe: Double?
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            exerciseID: UUID,
            setIndex: Int,
            weightKG: Double,
            reps: Int? = nil,
            seconds: Int? = nil,
            rpe: Double? = nil,
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.exerciseID = exerciseID
            self.setIndex = setIndex
            self.weightKG = weightKG
            self.reps = reps
            self.seconds = seconds
            self.rpe = rpe
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct UndoLastSet: Codable, Hashable, Sendable {
        public var exerciseID: UUID?
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            exerciseID: UUID? = nil,
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.exerciseID = exerciseID
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct PauseSession: Codable, Hashable, Sendable {
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct ResumeSession: Codable, Hashable, Sendable {
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct SkipRest: Codable, Hashable, Sendable {
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct AdvanceExercise: Codable, Hashable, Sendable {
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID

        public init(
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID()
        ) {
            self.at = at
            self.source = source
            self.operationID = operationID
        }
    }

    public struct FinishSession: Codable, Hashable, Sendable {
        public var at: Date
        public var source: WorkoutCommandSource
        public var operationID: UUID
        public var discard: Bool

        public init(
            at: Date,
            source: WorkoutCommandSource,
            operationID: UUID = UUID(),
            discard: Bool = false
        ) {
            self.at = at
            self.source = source
            self.operationID = operationID
            self.discard = discard
        }
    }

    public var operationID: UUID {
        switch self {
        case .completeSet(let value): return value.operationID
        case .undoLastSet(let value): return value.operationID
        case .pause(let value): return value.operationID
        case .resume(let value): return value.operationID
        case .skipRest(let value): return value.operationID
        case .advanceExercise(let value): return value.operationID
        case .finish(let value): return value.operationID
        }
    }

    public var source: WorkoutCommandSource {
        switch self {
        case .completeSet(let value): return value.source
        case .undoLastSet(let value): return value.source
        case .pause(let value): return value.source
        case .resume(let value): return value.source
        case .skipRest(let value): return value.source
        case .advanceExercise(let value): return value.source
        case .finish(let value): return value.source
        }
    }
}

public enum WorkoutEvent: Codable, Hashable, Sendable {
    case setCompleted(WorkoutSetRecord)
    case setUndone(WorkoutSetRecord)
    case restStarted(until: Date)
    case restSkipped
    case sessionPaused
    case sessionResumed
    case exerciseCompleted(UUID)
    case exerciseAdvanced(index: Int)
    case sessionFinished
    case duplicateIgnored
}

public struct WorkoutTransition: Equatable, Sendable {
    public var snapshot: WorkoutSessionSnapshot
    public var events: [WorkoutEvent]

    public init(snapshot: WorkoutSessionSnapshot, events: [WorkoutEvent]) {
        self.snapshot = snapshot
        self.events = events
    }
}

public enum WorkoutEngineError: Error, Equatable, Sendable {
    case sessionEnded
    case exerciseNotFound
    case invalidSetIndex(expected: Int)
    case invalidSetValue
    case sessionPaused
    case sessionNotPaused
    case alreadyPaused
    case noSetsToUndo
}

/// Pure, deterministic workout state machine.
///
/// The engine never reads the wall clock: commands carry `Date`, so tests are
/// deterministic and both devices can replay the same command stream.
public struct WorkoutSessionEngine: Sendable {
    public private(set) var snapshot: WorkoutSessionSnapshot
    private var appliedOperations: Set<UUID>
    private static let appliedOperationLimit = 256

    public init(snapshot: WorkoutSessionSnapshot) {
        self.snapshot = snapshot
        self.appliedOperations = Set(snapshot.appliedOperationIDs)
    }

    @discardableResult
    public mutating func apply(_ command: WorkoutCommand) throws -> WorkoutTransition {
        if appliedOperations.contains(command.operationID) {
            return WorkoutTransition(snapshot: snapshot, events: [.duplicateIgnored])
        }
        if snapshot.isFinished {
            throw WorkoutEngineError.sessionEnded
        }

        let events: [WorkoutEvent]
        switch command {
        case .completeSet(let value):
            events = try applyCompleteSet(value)
        case .undoLastSet(let value):
            events = try applyUndo(value)
        case .pause(let value):
            events = try applyPause(value)
        case .resume(let value):
            events = try applyResume(value)
        case .skipRest(let value):
            events = try applySkipRest(value)
        case .advanceExercise(let value):
            events = try applyAdvance(value)
        case .finish(let value):
            events = try applyFinish(value)
        }

        remember(command.operationID)
        snapshot.revision += 1
        return WorkoutTransition(snapshot: snapshot, events: events)
    }

    private mutating func applyCompleteSet(
        _ command: WorkoutCommand.CompleteSet
    ) throws -> [WorkoutEvent] {
        if snapshot.isPaused {
            throw WorkoutEngineError.sessionPaused
        }
        guard let exercise = snapshot.exercises.first(where: { $0.id == command.exerciseID }) else {
            throw WorkoutEngineError.exerciseNotFound
        }
        guard command.weightKG.isFinite, command.weightKG >= 0,
              (command.reps ?? 1) > 0,
              (command.seconds ?? 1) > 0 else {
            throw WorkoutEngineError.invalidSetValue
        }

        let completed = snapshot.completedSets(for: exercise.id)
        guard command.setIndex == completed + 1 else {
            if command.setIndex <= completed {
                return [.duplicateIgnored]
            }
            throw WorkoutEngineError.invalidSetIndex(expected: completed + 1)
        }

        let record = WorkoutSetRecord(
            exerciseID: exercise.id,
            exerciseSlug: exercise.slug,
            setIndex: command.setIndex,
            weightKG: command.weightKG,
            reps: command.reps,
            seconds: command.seconds,
            rpe: command.rpe,
            completedAt: command.at,
            source: command.source,
            operationID: command.operationID
        )
        snapshot.sets.append(record)
        snapshot.status = .active
        snapshot.isPaused = false

        var events: [WorkoutEvent] = [.setCompleted(record)]
        if exercise.restSeconds > 0 {
            let restEnd = command.at.addingTimeInterval(TimeInterval(exercise.restSeconds))
            snapshot.restEndsAt = restEnd
            snapshot.pausedRestRemaining = nil
            events.append(.restStarted(until: restEnd))
        } else {
            snapshot.restEndsAt = nil
            snapshot.pausedRestRemaining = nil
        }

        if snapshot.completedSets(for: exercise.id) >= exercise.sets {
            events.append(.exerciseCompleted(exercise.id))
        }
        return events
    }

    private mutating func applyUndo(
        _ command: WorkoutCommand.UndoLastSet
    ) throws -> [WorkoutEvent] {
        let index: Int?
        if let exerciseID = command.exerciseID {
            index = snapshot.sets.lastIndex(where: { $0.exerciseID == exerciseID })
        } else {
            index = snapshot.sets.indices.last
        }
        guard let index else {
            throw WorkoutEngineError.noSetsToUndo
        }
        let removed = snapshot.sets.remove(at: index)
        snapshot.restEndsAt = nil
        snapshot.pausedRestRemaining = nil
        snapshot.status = .active
        snapshot.isPaused = false
        return [.setUndone(removed)]
    }

    private mutating func applyPause(
        _ command: WorkoutCommand.PauseSession
    ) throws -> [WorkoutEvent] {
        guard !snapshot.isPaused else {
            throw WorkoutEngineError.alreadyPaused
        }
        snapshot.pausedRestRemaining = nil
        if let restEndsAt = snapshot.restEndsAt {
            snapshot.pausedRestRemaining = max(
                0,
                restEndsAt.timeIntervalSince(command.at)
            )
        }
        snapshot.restEndsAt = nil
        snapshot.isPaused = true
        snapshot.status = .paused
        return [.sessionPaused]
    }

    private mutating func applyResume(
        _ command: WorkoutCommand.ResumeSession
    ) throws -> [WorkoutEvent] {
        guard snapshot.isPaused else {
            throw WorkoutEngineError.sessionNotPaused
        }
        snapshot.isPaused = false
        snapshot.status = .active
        if let remaining = snapshot.pausedRestRemaining, remaining > 0 {
            snapshot.restEndsAt = command.at.addingTimeInterval(remaining)
        }
        snapshot.pausedRestRemaining = nil
        return [.sessionResumed]
    }

    private mutating func applySkipRest(
        _ command: WorkoutCommand.SkipRest
    ) throws -> [WorkoutEvent] {
        guard snapshot.restEndsAt != nil || snapshot.pausedRestRemaining != nil else {
            return [.duplicateIgnored]
        }
        snapshot.restEndsAt = nil
        snapshot.pausedRestRemaining = nil
        if snapshot.isPaused {
            snapshot.status = .paused
        } else {
            snapshot.status = .active
        }
        return [.restSkipped]
    }

    private mutating func applyAdvance(
        _ command: WorkoutCommand.AdvanceExercise
    ) throws -> [WorkoutEvent] {
        guard !snapshot.exercises.isEmpty else {
            throw WorkoutEngineError.exerciseNotFound
        }
        snapshot.restEndsAt = nil
        snapshot.pausedRestRemaining = nil
        snapshot.isPaused = false
        snapshot.status = .active
        snapshot.currentExerciseIndex = min(
            snapshot.currentExerciseIndex + 1,
            snapshot.exercises.count
        )
        return [.exerciseAdvanced(index: snapshot.currentExerciseIndex)]
    }

    private mutating func applyFinish(
        _ command: WorkoutCommand.FinishSession
    ) throws -> [WorkoutEvent] {
        snapshot.restEndsAt = nil
        snapshot.pausedRestRemaining = nil
        snapshot.isPaused = false
        snapshot.finishedAt = command.at
        snapshot.status = command.discard ? .discarded : .finished
        return [.sessionFinished]
    }

    private mutating func remember(_ operationID: UUID) {
        appliedOperations.insert(operationID)
        snapshot.appliedOperationIDs.append(operationID)
        if snapshot.appliedOperationIDs.count > Self.appliedOperationLimit {
            let overflow = snapshot.appliedOperationIDs.count - Self.appliedOperationLimit
            let removed = Set(snapshot.appliedOperationIDs.prefix(overflow))
            snapshot.appliedOperationIDs.removeFirst(overflow)
            appliedOperations.subtract(removed)
        }
    }
}
