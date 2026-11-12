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

    func updateFoodLog(_ log: FoodLog) {
        guard let index = foodLogs.firstIndex(where: { $0.id == log.id }) else {
            return
        }
        var updated = log
        // Re-sync the edited row with the server; the client_id is the upsert key.
        updated.syncedAt = nil
        foodLogs[index] = updated
        foodLogs.sort { $0.date > $1.date }
        persist()
        syncPendingUserData()
    }

    func removeFoodLog(_ id: UUID) {
        foodLogs.removeAll { $0.id == id }
        let key = id.uuidString
        if !pendingFoodDeletionIDs.contains(key) {
            pendingFoodDeletionIDs.append(key)
        }
        persist()
        syncPendingUserData()
    }
}
