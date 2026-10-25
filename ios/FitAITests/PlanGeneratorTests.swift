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

    func testLowCompletionReducesSets() {
        let plan = PlanGenerator.generate(profile: makeProfile())
        let adjusted = PlanGenerator.adjusted(
            plan: plan,
            profile: makeProfile(),
            completionRate: 0.3,
            averageRPE: 7
        ).plan

        let original = plan.days.first?.exercises.first
        let changed = adjusted.days.first?.exercises.first

        guard let original, let changed else {
            return XCTFail("计划为空")
        }
        XCTAssertEqual(changed.sets, max(2, original.sets - 1))
        XCTAssertGreaterThan(adjusted.version, plan.version)
    }

    func testHighRPELowersLoad() {
        let plan = PlanGenerator.generate(profile: makeProfile())
        let adjusted = PlanGenerator.adjusted(
            plan: plan,
            profile: makeProfile(),
            completionRate: 0.9,
            averageRPE: 9.5
        ).plan

        guard let oldItem = plan.days.flatMap(\.exercises).first(where: { ($0.weightKG ?? 0) > 0 }),
              let newItem = adjusted.days
                .flatMap(\.exercises)
                .first(where: { $0.slug == oldItem.slug && ($0.weightKG ?? 0) > 0 }) else {
            XCTFail("计划中没有带重量的动作")
            return
        }

        XCTAssertLessThan(newItem.weightKG ?? 0, oldItem.weightKG ?? 0)
    }

    func testHighCompletionAndLowRPELoadsMore() {
        let plan = PlanGenerator.generate(profile: makeProfile())
        let adjusted = PlanGenerator.adjusted(
            plan: plan,
            profile: makeProfile(),
            completionRate: 0.9,
            averageRPE: 7.5
        ).plan

        guard let oldItem = plan.days.flatMap(\.exercises).first(where: { ($0.weightKG ?? 0) > 0 }),
              let newItem = adjusted.days
                .flatMap(\.exercises)
                .first(where: { $0.slug == oldItem.slug && ($0.weightKG ?? 0) > 0 }) else {
            XCTFail("计划中没有带重量的动作")
            return
        }

        XCTAssertGreaterThan(newItem.weightKG ?? 0, oldItem.weightKG ?? 0)
    }
}
