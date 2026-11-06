import XCTest
@testable import FitAIWorkoutCore

final class WorkoutSessionEngineTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let firstExerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    private let secondExerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

    private func makeEngine() -> WorkoutSessionEngine {
        let exercises = [
            WorkoutExercise(
                id: firstExerciseID,
                slug: "bench_press",
                name: "卧推",
                target: .reps(min: 8, max: 10),
                sets: 2,
                weightKG: 60,
                restSeconds: 60,
                equipment: "杠铃"
            ),
            WorkoutExercise(
                id: secondExerciseID,
                slug: "plank",
                name: "平板支撑",
                target: .time(seconds: 30),
                sets: 3,
                restSeconds: 45,
                isBodyweight: true,
                equipment: "自重"
            )
        ]
        return WorkoutSessionEngine(
            snapshot: WorkoutSessionSnapshot(
                programDayID: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
                dayTitle: "推",
                startedAt: start,
                exercises: exercises
            )
        )
    }

    private func completeFirstSet(
        in engine: inout WorkoutSessionEngine,
        at date: Date? = nil,
        operationID: UUID = UUID()
    ) throws -> WorkoutTransition {
        try engine.apply(
            .completeSet(
                .init(
                    exerciseID: firstExerciseID,
                    setIndex: 1,
                    weightKG: 60,
                    reps: 10,
                    rpe: 7.5,
                    at: date ?? start,
                    source: .watch,
                    operationID: operationID
                )
            )
        )
    }

    func testCompleteSetStartsRestAndRecordsSet() throws {
        var engine = makeEngine()
        let transition = try completeFirstSet(in: &engine)

        XCTAssertEqual(transition.snapshot.sets.count, 1)
        XCTAssertEqual(transition.snapshot.sets.first?.setIndex, 1)
        XCTAssertEqual(
            transition.snapshot.sets.first?.source,
            WorkoutCommandSource.watch
        )
        XCTAssertEqual(transition.snapshot.restEndsAt, start.addingTimeInterval(60))
        XCTAssertEqual(transition.snapshot.revision, 1)
        XCTAssertEqual(
            transition.events,
            [
                .setCompleted(transition.snapshot.sets[0]),
                .restStarted(until: start.addingTimeInterval(60))
            ]
        )
    }

    func testDuplicateOperationIsIgnoredWithoutMutatingRevision() throws {
        var engine = makeEngine()
        let operationID = UUID()
        _ = try completeFirstSet(in: &engine, operationID: operationID)
        let revision = engine.snapshot.revision

        let duplicate = try completeFirstSet(in: &engine, operationID: operationID)

        XCTAssertEqual(duplicate.events, [.duplicateIgnored])
        XCTAssertEqual(duplicate.snapshot.sets.count, 1)
        XCTAssertEqual(duplicate.snapshot.revision, revision)
    }

    func testDuplicateSetFromDifferentOperationDoesNotDuplicateTheSet() throws {
        var engine = makeEngine()
        _ = try completeFirstSet(in: &engine)
        let duplicate = try completeFirstSet(in: &engine, operationID: UUID())

        XCTAssertEqual(duplicate.events, [.duplicateIgnored])
        XCTAssertEqual(duplicate.snapshot.sets.count, 1)
    }

    func testPausePreservesRestAndResumeRestoresIt() throws {
        var engine = makeEngine()
        _ = try completeFirstSet(in: &engine)

        let pausedAt = start.addingTimeInterval(20)
        _ = try engine.apply(
            .pause(.init(at: pausedAt, source: .watch, operationID: UUID()))
        )
        XCTAssertTrue(engine.snapshot.isPaused)
        XCTAssertEqual(engine.snapshot.remainingRest(at: pausedAt), 40)

        let resumedAt = start.addingTimeInterval(120)
        _ = try engine.apply(
            .resume(.init(at: resumedAt, source: .watch, operationID: UUID()))
        )
        XCTAssertFalse(engine.snapshot.isPaused)
        XCTAssertEqual(
            engine.snapshot.restEndsAt,
            resumedAt.addingTimeInterval(40)
        )
        XCTAssertEqual(
            engine.snapshot.remainingRest(at: resumedAt.addingTimeInterval(10)),
            30
        )
    }

    func testUndoLastSetClearsRestAndRemovesRecord() throws {
        var engine = makeEngine()
        _ = try completeFirstSet(in: &engine)

        let transition = try engine.apply(
            .undoLastSet(
                .init(
                    exerciseID: firstExerciseID,
                    at: start.addingTimeInterval(5),
                    source: .phone,
                    operationID: UUID()
                )
            )
        )

        XCTAssertTrue(transition.snapshot.sets.isEmpty)
        XCTAssertNil(transition.snapshot.restEndsAt)
        guard case .setUndone(let removed)? = transition.events.first else {
            XCTFail("expected setUndone event")
            return
        }
        XCTAssertEqual(removed.setIndex, 1)
        XCTAssertEqual(removed.exerciseID, firstExerciseID)
    }

    func testSkipRestClearsRest() throws {
        var engine = makeEngine()
        _ = try completeFirstSet(in: &engine)

        let transition = try engine.apply(
            .skipRest(.init(at: start, source: .watch, operationID: UUID()))
        )

        XCTAssertNil(transition.snapshot.restEndsAt)
        XCTAssertEqual(transition.events, [.restSkipped])
    }

    func testAdvanceAndFinish() throws {
        var engine = makeEngine()
        _ = try completeFirstSet(in: &engine)

        let advanced = try engine.apply(
            .advanceExercise(.init(at: start, source: .watch, operationID: UUID()))
        )
        XCTAssertEqual(advanced.snapshot.currentExerciseIndex, 1)
        XCTAssertEqual(advanced.snapshot.currentExercise?.slug, "plank")

        let finished = try engine.apply(
            .finish(.init(at: start, source: .watch, operationID: UUID()))
        )
        XCTAssertEqual(finished.snapshot.status, .finished)
        XCTAssertEqual(finished.snapshot.finishedAt, start)
        XCTAssertEqual(finished.events, [.sessionFinished])
    }

    func testInvalidSetIndexThrowsExpectedIndex() {
        var engine = makeEngine()

        XCTAssertThrowsError(
            try engine.apply(
                .completeSet(
                    .init(
                        exerciseID: firstExerciseID,
                        setIndex: 2,
                        weightKG: 60,
                        reps: 10,
                        at: start,
                        source: .watch,
                        operationID: UUID()
                    )
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? WorkoutEngineError,
                WorkoutEngineError.invalidSetIndex(expected: 1)
            )
        }
    }

    func testTimedAndUnilateralFieldsSurviveCoding() throws {
        let exercise = WorkoutExercise(
            slug: "single_leg_rdl",
            name: "单腿硬拉",
            target: .reps(min: 10, max: 12),
            sets: 3,
            weightKG: 20,
            restSeconds: 45,
            isUnilateral: true
        )
        let snapshot = WorkoutSessionSnapshot(
            programDayID: UUID(),
            dayTitle: "腿",
            startedAt: start,
            exercises: [exercise]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WorkoutSessionSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertTrue(decoded.exercises[0].isUnilateral)
        XCTAssertEqual(decoded.exercises[0].target, .reps(min: 10, max: 12))
    }

    func testCurrentAndNextExerciseDerivedValues() {
        let engine = makeEngine()
        let snapshot = engine.snapshot

        XCTAssertEqual(snapshot.currentExercise?.slug, "bench_press")
        XCTAssertEqual(snapshot.nextExercise?.slug, "plank")
        XCTAssertEqual(snapshot.plannedSetCount, 5)
        XCTAssertEqual(snapshot.currentSetIndex(for: snapshot.exercises[0]), 1)
        XCTAssertEqual(snapshot.remainingSets(for: snapshot.exercises[0]), 2)
    }
}
