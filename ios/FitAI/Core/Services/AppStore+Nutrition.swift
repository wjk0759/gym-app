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
