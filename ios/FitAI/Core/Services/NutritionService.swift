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

    /// 生成/重排某天餐单；`idempotencyKey` 由页面在成功前复用。
    func fetchPlan(
        dateString: String,
        idempotencyKey: String? = nil
    ) async throws -> RemoteDietPlan {
        try await client.fetchDietPlan(
            dateString: dateString,
            idempotencyKey: idempotencyKey
        )
    }

    /// 只读已保存计划；没有保存过时返回 nil，不触发生成。
    func fetchSavedPlan(dateString: String) async throws -> RemoteDietPlan? {
        try await client.fetchSavedDietPlan(dateString: dateString)
    }

    func swapMeal(dateString: String, meal: MealType) async throws -> RemoteDietPlan {
        try await client.swapDietMeal(dateString: dateString, meal: meal)
    }

    func restoreMeal(dateString: String, meal: MealType) async throws -> RemoteDietPlan {
        try await client.restoreDietMeal(dateString: dateString, meal: meal)
    }

    func undoSwapMeal(dateString: String, meal: MealType) async throws -> RemoteDietPlan {
        try await client.undoSwapDietMeal(dateString: dateString, meal: meal)
    }

    func fetchTargets(dateString: String) async throws -> RemoteDietTargets {
        try await client.fetchDietTargets(dateString: dateString)
    }

    func fetchReview(from: String, to: String) async throws -> RemoteDietReview {
        try await client.fetchDietReview(from: from, to: to)
    }

    /// 生成一周餐单；`weekStart` 为空时由服务端决定默认周。
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

    /// 只读已保存周计划；没有保存过时返回空 days，由页面展示生成入口。
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
            planMeal: item.planMeal.flatMap(MealType.init(rawValue:)),
            sourceActionID: item.sourceActionID
        )
    }
}
