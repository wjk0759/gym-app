import XCTest
@testable import FitAI

final class PlanGeneratorTests: XCTestCase {
    private func makeProfile(
        weeklyDays: Int = 3,
        equipment: Set<Equipment> = [.bodyweight, .dumbbell],
        injuries: String = "",
        goal: GoalType = .buildMuscle
    ) -> UserProfile {
        var profile = UserProfile()
        profile.isOnboarded = true
        profile.nickname = "测试用户"
        profile.weeklyDays = weeklyDays
        profile.equipment = equipment
        profile.injuries = injuries
        profile.goalType = goal
        profile.sessionMinutes = 45
        return profile
    }

    func testGeneratesFourWeeksWithExpectedTrainingDays() {
        let profile = makeProfile(weeklyDays: 3)
        let plan = PlanGenerator.generate(profile: profile)

        XCTAssertEqual(plan.weeks, 4)
        XCTAssertEqual(plan.days.count, 12)
        XCTAssertEqual(plan.firstWeek.count, 3)

        for day in plan.days {
            XCTAssertGreaterThanOrEqual(day.exercises.count, 4)
            XCTAssertLessThanOrEqual(day.exercises.count, 6)
            XCTAssertTrue(day.weekday >= 1 && day.weekday <= 7)
        }
    }

    func testKneeInjuryExcludesContraindicatedExercises() {
        let profile = makeProfile(injuries: "右膝半月板旧伤")
        let plan = PlanGenerator.generate(profile: profile)
        let slugs = Set(plan.days.flatMap { $0.exercises.map(\.slug) })

        XCTAssertFalse(slugs.contains("squat"))
        XCTAssertFalse(slugs.contains("lunge"))
        XCTAssertFalse(slugs.contains("leg_press"))
    }

    func testDislikedExerciseIsAvoided() {
        var profile = makeProfile()
        profile.equipment = [.bodyweight, .dumbbell, .machine, .cable]
        let plan = PlanGenerator.generate(
            profile: profile,
            dislikedSlugs: ["pushup"]
        )
        let slugs = Set(plan.days.flatMap { $0.exercises.map(\.slug) })

        XCTAssertFalse(slugs.contains("pushup"))
    }

    func testFocusAreasArePrioritisedAcrossTrainingDays() {
        var profile = makeProfile(
            weeklyDays: 3,
            equipment: [.bodyweight, .dumbbell, .machine, .cable]
        )
        profile.split = .three

        let baseline = PlanGenerator.generate(profile: profile)
        XCTAssertFalse(baseline.days.allSatisfy { $0.focus.contains(.arms) })

        let focused = PlanGenerator.generate(
            profile: profile,
            focusAreas: [.arms]
        )
        XCTAssertTrue(focused.days.allSatisfy { $0.focus.contains(.arms) })
    }

    func testLowCompletionReducesSets() {
        let adjustment = PlanGenerator.adjustment(
            completionRate: 0.3,
            averageRPE: 7
        )

        XCTAssertEqual(adjustment.setsDelta, -1)
        XCTAssertEqual(adjustment.weightMultiplier, 1.0)
    }

    func testHighRPELowersLoad() {
        let adjustment = PlanGenerator.adjustment(
            completionRate: 0.9,
            averageRPE: 9.5
        )

        XCTAssertEqual(adjustment.setsDelta, 0)
        XCTAssertLessThan(adjustment.weightMultiplier, 1.0)
    }

    func testHighCompletionAndLowRPELoadsMore() {
        let adjustment = PlanGenerator.adjustment(
            completionRate: 0.9,
            averageRPE: 7.5
        )

        XCTAssertEqual(adjustment.setsDelta, 0)
        XCTAssertGreaterThan(adjustment.weightMultiplier, 1.0)
    }
}
