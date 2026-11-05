import XCTest

@testable import FitAI

final class LoadProgressionTests: XCTestCase {
    func testRepRangeParsing() {
        XCTAssertEqual(LoadProgression.parseRepRange("8-10"), 8...10)
        XCTAssertEqual(LoadProgression.parseRepRange("12"), 12...12)
    }

    func testHistoryUsesLatestWorkingSet() {
        let newer = WorkoutSession(
            date: Date(),
            dayTitle: "推",
            durationMinutes: 40,
            feeling: 3,
            sets: [
                SetLog(slug: "bench", setIndex: 1, weightKG: 60, reps: 8, rpe: 8)
            ]
        )
        let older = WorkoutSession(
            date: Date().addingTimeInterval(-86_400),
            dayTitle: "推",
            durationMinutes: 40,
            feeling: 3,
            sets: [
                SetLog(slug: "bench", setIndex: 1, weightKG: 50, reps: 8, rpe: 9)
            ]
        )

        let history = LoadProgression.history(from: [older, newer])

        XCTAssertEqual(history["bench"]?.lastWeightKG, 60)
        XCTAssertEqual(history["bench"]?.lastReps, 8)
        XCTAssertEqual(history["bench"]?.lastRPE, 8)
    }

    func testStageProgressionUsesPerExerciseAnchor() {
        var profile = UserProfile()
        profile.weightKG = 70
        profile.experience = .beginner
        profile.trainingStage = .beginner
        let bench = Exercise(
            slug: "bench",
            nameZH: "哑铃卧推",
            muscle: .chest,
            equipment: .dumbbell,
            isCompound: true,
            instructions: ""
        )
        let squat = Exercise(
            slug: "squat",
            nameZH: "深蹲",
            muscle: .legs,
            equipment: .barbell,
            isCompound: true,
            instructions: ""
        )
        let benchHistory = LoadProgression.Performance(
            lastWeightKG: 60,
            lastReps: 8,
            lastRPE: 8,
            lastDate: Date(),
            sessionCount: 3
        )
        let squatHistory = LoadProgression.Performance(
            lastWeightKG: 100,
            lastReps: 8,
            lastRPE: 8,
            lastDate: Date(),
            sessionCount: 3
        )

        XCTAssertEqual(
            LoadProgression.targetWeight(
                exercise: bench,
                profile: profile,
                history: benchHistory,
                weekIndex: 2,
                reps: "8-10"
            ),
            61.5
        )
        XCTAssertEqual(
            LoadProgression.targetWeight(
                exercise: squat,
                profile: profile,
                history: squatHistory,
                weekIndex: 2,
                reps: "8-10"
            ),
            105
        )
    }

    func testBodyweightHasNoTargetWeight() {
        var profile = UserProfile()
        profile.trainingStage = .beginner
        let pullUp = Exercise(
            slug: "pull_up",
            nameZH: "引体向上",
            muscle: .back,
            equipment: .bodyweight,
            isCompound: true,
            instructions: ""
        )

        XCTAssertNil(
            LoadProgression.targetWeight(
                exercise: pullUp,
                profile: profile,
                history: nil,
                weekIndex: 1,
                reps: "8-10"
            )
        )
    }
}
