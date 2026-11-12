import Foundation

/// API and mapping boundary for food logs. AppStore owns merge/order and local
/// pending timestamps; this service only performs the network call and converts
/// remote rows into local `FoodLog` values.
struct NutritionService {
    var client: APIClient = .shared

    func push(_ log: FoodLog) async throws {
        try await client.syncFoodLog(log)
    }

    func fetchRemote() async throws -> [RemoteFoodLog] {
        try await client.fetchFoodLogs()
    }

    func fetchPlan(
        dateString: String,
        idempotencyKey: String? = nil
    ) async throws -> RemoteDietPlan {
        try await client.fetchDietPlan(
            dateString: dateString,
            idempotencyKey: idempotencyKey
        )
    }

    func fetchSavedPlan(dateString: String) async throws -> RemoteDietPlan? {
        try await client.fetchSavedDietPlan(dateString: dateString)
    }

    func swapMeal(dateString: String, meal: MealType) async throws -> RemoteDietPlan {
        try await client.swapDietMeal(dateString: dateString, meal: meal)
    }

    func fetchTargets(dateString: String) async throws -> RemoteDietTargets {
        try await client.fetchDietTargets(dateString: dateString)
    }

    func fetchReview(from: String, to: String) async throws -> RemoteDietReview {
        try await client.fetchDietReview(from: from, to: to)
    }

    func fetchWeek(
        strategy: String,
        weekStart: String?,
        idempotencyKey: String? = nil
    ) async throws -> RemoteDietWeek {
        try await client.fetchDietWeek(
            strategy: strategy,
            weekStart: weekStart,
            idempotencyKey: idempotencyKey
        )
    }

    func fetchSavedWeek(weekStart: String?) async throws -> RemoteDietWeek {
        try await client.fetchSavedDietWeek(weekStart: weekStart)
    }

    func makeFoodLog(from item: RemoteFoodLog) -> FoodLog? {
        guard let id = UUID(uuidString: item.clientID),
              let meal = MealType(rawValue: item.meal) else {
            return nil
        }
        return FoodLog(
            id: id,
            date: item.loggedAt,
            meal: meal,
            foodName: item.foodName,
            grams: item.grams,
            kcal: item.kcal,
            protein: item.protein,
            carbs: item.carbs,
            fat: item.fat,
            fiber: item.fiber,
            syncedAt: Date(),
            planDate: item.planDate,
            planMeal: item.planMeal.flatMap(MealType.init(rawValue:))
        )
    }
}
