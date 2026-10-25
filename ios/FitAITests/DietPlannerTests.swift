import XCTest
@testable import FitAI

final class DietPlannerTests: XCTestCase {
    private func makeProfile(goal: GoalType = .buildMuscle) -> UserProfile {
        var profile = UserProfile()
        profile.weightKG = 70
        profile.heightCM = 175
        profile.age = 30
        profile.sex = .male
        profile.weeklyDays = 3
        profile.goalType = goal
        return profile
    }

    func testMacrosApproximatelyMatchCalories() {
        let targets = DietPlanner.targets(profile: makeProfile())
        let macroCalories = Double(
            targets.protein * 4 + targets.carbs * 4 + targets.fat * 9
        )

        XCTAssertGreaterThan(targets.kcal, 1500)
        XCTAssertEqual(macroCalories, Double(targets.kcal), accuracy: 40)
    }

    func testMealSplitMatchesTargetCalories() {
        let targets = DietPlanner.targets(profile: makeProfile())
        let meals = DietPlanner.meals(profile: makeProfile())
        let mealCalories = meals.reduce(0) { $0 + $1.kcal }

        XCTAssertEqual(meals.count, 4)
        XCTAssertEqual(Double(mealCalories), Double(targets.kcal), accuracy: 10)
    }

    func testFatLossTargetIsLowerThanBuildMuscle() {
        let cut = DietPlanner.targets(profile: makeProfile(goal: .loseFat))
        let bulk = DietPlanner.targets(profile: makeProfile(goal: .buildMuscle))

        XCTAssertLessThan(cut.kcal, bulk.kcal)
    }
}
