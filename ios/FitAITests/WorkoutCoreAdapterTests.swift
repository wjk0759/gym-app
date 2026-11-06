import XCTest
import FitAIWorkoutCore
@testable import FitAI

final class WorkoutCoreAdapterTests: XCTestCase {
    func testPlanDayMapsIntoSharedSnapshot() {
        let first = PlanExercise(
            slug: "bench_press",
            sets: 3,
            reps: "8-10",
            weightKG: 60,
            restSec: 90,
            rpe: 7.5
        )
        let second = PlanExercise(
            slug: "plank",
            sets: 3,
            reps: "30秒",
            weightKG: nil,
            restSec: 45,
            rpe: 6
        )
        let day = PlanDay(
            weekday: 1,
            title: "推",
            focus: [.chest],
            exercises: [first, second]
        )

        let snapshot = WorkoutSessionSnapshot(day: day)

        XCTAssertEqual(snapshot.programDayID, day.id)
        XCTAssertEqual(snapshot.dayTitle, "推")
        XCTAssertEqual(snapshot.exercises.count, 2)
        XCTAssertEqual(snapshot.exercises[0].target, .reps(min: 8, max: 10))
        XCTAssertEqual(snapshot.exercises[1].target, .time(seconds: 30))
        XCTAssertEqual(snapshot.exercises[0].restSeconds, 90)
        XCTAssertEqual(snapshot.exercises[1].restSeconds, 45)
    }

    func testTimedTargetUsesSeconds() {
        let exercise = PlanExercise(
            slug: "plank",
            sets: 3,
            reps: "45秒",
            weightKG: nil,
            restSec: 30,
            rpe: 6
        )

        let mapped = WorkoutExercise(planExercise: exercise)

        XCTAssertEqual(mapped.target, .time(seconds: 45))
    }

    func testRepsTextIsNotMistakenForTime() {
        let exercise = PlanExercise(
            slug: "row",
            sets: 3,
            reps: "10 reps",
            weightKG: 40,
            restSec: 60,
            rpe: 7
        )

        let mapped = WorkoutExercise(planExercise: exercise)

        XCTAssertEqual(mapped.target, .reps(min: 10, max: 10))
    }

    func testUnilateralNameIsPreserved() {
        let exercise = PlanExercise(
            slug: "single_leg_rdl",
            sets: 3,
            reps: "每侧 10-12",
            weightKG: 20,
            restSec: 60,
            rpe: 7
        )

        let mapped = WorkoutExercise(planExercise: exercise)

        XCTAssertTrue(mapped.isUnilateral)
        XCTAssertEqual(mapped.target, .reps(min: 10, max: 12))
    }
}
