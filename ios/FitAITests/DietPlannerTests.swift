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

    func testMealMacrosSplitAcrossMeals() {
        let targets = DietPlanner.targets(profile: makeProfile())
        let meals = DietPlanner.meals(profile: makeProfile())

        XCTAssertEqual(
            Int(meals.reduce(0) { $0 + $1.protein }),
            targets.protein,
            accuracy: 2
        )
        XCTAssertEqual(meals.first?.meal, MealType.breakfast)
        XCTAssertEqual(meals.last?.meal, MealType.snack)
        XCTAssertTrue(meals.allSatisfy { $0.kcal > 0 })
    }

    func testFoodLogRoundTripsPlanLink() throws {
        let log = FoodLog(
            date: Date(),
            meal: .lunch,
            foodName: "午餐（计划餐）",
            grams: 0,
            kcal: 620,
            protein: 42,
            carbs: 68,
            fat: 18,
            planDate: Date(),
            planMeal: .lunch
        )

        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(FoodLog.self, from: data)

        XCTAssertEqual(decoded.planMeal, MealType.lunch)
        XCTAssertNotNil(decoded.planDate)
    }

    func testFatLossTargetIsLowerThanBuildMuscle() {
        let cut = DietPlanner.targets(profile: makeProfile(goal: .loseFat))
        let bulk = DietPlanner.targets(profile: makeProfile(goal: .buildMuscle))

        XCTAssertLessThan(cut.kcal, bulk.kcal)
    }
}
