import Foundation

extension AppStore {
    // MARK: - Nutrition

    func addFoodLog(_ log: FoodLog) {
        foodLogs.insert(log, at: 0)
        persist()
        syncPendingUserData()
    }

    func addFoodLogs(_ logs: [FoodLog]) {
        guard !logs.isEmpty else { return }
        foodLogs.insert(contentsOf: logs, at: 0)
        persist()
        syncPendingUserData()
    }

    func addCustomFood(_ food: FoodItem) {
        customFoods.removeAll { $0.name == food.name }
        customFoods.insert(food, at: 0)
        persist()
    }

    func isFavoriteFood(_ food: FoodItem) -> Bool {
        favoriteFoods.contains { $0.name == food.name }
    }

    func toggleFavoriteFood(_ food: FoodItem) {
        if isFavoriteFood(food) {
            favoriteFoods.removeAll { $0.name == food.name }
        } else {
            favoriteFoods.removeAll { $0.name == food.name }
            favoriteFoods.insert(food, at: 0)
        }
        persist()
    }

    /// Most recently logged foods, resolved back to library items so they keep
    /// their per-100g nutrition and default serving.
    func recentFoodItems(limit: Int = 6) -> [FoodItem] {
        var seen = Set<String>()
        var result: [FoodItem] = []
        let library = customFoods + FoodLibrary.all
        for log in foodLogs.sorted(by: { $0.date > $1.date }) {
            guard log.planDate == nil,
                  seen.insert(log.foodName).inserted else { continue }
            guard let food = library.first(where: { $0.name == log.foodName }) else {
                continue
            }
            result.append(food)
            if result.count >= limit { break }
        }
        return result
    }

    /// One-tap planned-meal logging shared by the nutrition page and the coach
    /// diet card. Duplicate checks live here so every entry point behaves the same.
    @MainActor
    func refreshDailyNutritionTargets(date: Date = Date()) async {
        guard AuthTokenStore.shared.accessToken != nil else { return }
        let key = FitnessDate.key(date)
        guard let response = try? await NutritionService().fetchTargets(
            dateString: key
        ), let targets = NutritionTargets(
            remote: response.targets,
            profile: profile
        ) else { return }
        guard key == FitnessDate.key(Date()) else { return }
        dailyNutritionTargets = targets
        dailyNutritionTargetsKey = key
        persist()
    }

    func cacheDailyNutritionTargets(_ targets: NutritionTargets, dateString: String) {
        guard dateString == FitnessDate.key(Date()) else { return }
        dailyNutritionTargets = targets
        dailyNutritionTargetsKey = dateString
        persist()
    }

    @discardableResult
    func logPlannedMeal(
        date: Date,
        meal: MealType,
        name: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double = 0
    ) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        let alreadyLogged = foodLogs.contains { log in
            guard log.planMeal == meal, let planDate = log.planDate else {
                return false
            }
            return Calendar.current.startOfDay(for: planDate) == day
        }
        guard !alreadyLogged else { return false }
        addFoodLog(
            FoodLog(
                date: day,
                meal: meal,
                foodName: "\(name)（计划餐）",
                grams: 0,
                kcal: kcal,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                planDate: day,
                planMeal: meal
            )
        )
        return true
    }

    func updateFoodLog(_ log: FoodLog) {
        guard let index = foodLogs.firstIndex(where: { $0.id == log.id }) else {
            return
        }
        var updated = log
        // Re-sync the edited row with the server; the client_id is the upsert key.
        updated.syncedAt = nil
        foodLogs[index] = updated
        let key = updated.id.uuidString
        if !pendingFoodUpdateIDs.contains(key) {
            pendingFoodUpdateIDs.append(key)
        }
        foodLogs.sort { $0.date > $1.date }
        persist()
        syncPendingUserData()
    }

    func removeFoodLog(_ id: UUID) {
        foodLogs.removeAll { $0.id == id }
        let key = id.uuidString
        pendingFoodUpdateIDs.removeAll { $0 == key }
        if !pendingFoodDeletionIDs.contains(key) {
            pendingFoodDeletionIDs.append(key)
        }
        persist()
        syncPendingUserData()
    }
}
