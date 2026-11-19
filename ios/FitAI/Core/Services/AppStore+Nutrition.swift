import Foundation

/// 饮食数据在 AppStore 中的唯一状态入口。
///
/// 负责目标缓存、FoodLog 合并、收藏/自定义食物和同步触发；
/// `NutritionView`、`AddFoodView`、拍照识别都通过这里写入，避免各自维护一份状态。
extension AppStore {
    // MARK: - Nutrition

    /// 新增一条本地饮食记录并触发同步。
    /// 先插入本地、再持久化、最后同步；远端合并由 `syncPendingUserData` 处理。
    func addFoodLog(_ log: FoodLog) {
        foodLogs.insert(log, at: 0)
        persist()
        syncPendingUserData()
        dataDidChange(.foodLog, refreshReview: false)
    }

    func addFoodLogs(_ logs: [FoodLog]) {
        guard !logs.isEmpty else { return }
        foodLogs.insert(contentsOf: logs, at: 0)
        persist()
        syncPendingUserData()
        dataDidChange(.foodLog, refreshReview: false)
    }

    /// One daily target for every screen. Prefer the server-confirmed cache
    /// for today; fall back to the local estimate only when offline or before
    /// the first server refresh.
    var currentNutritionTargets: NutritionTargets {
        let key = FitnessDate.key(Date())
        if let cached = nutritionTargetsByDate[key] {
            return cached
        }
        if dailyNutritionTargetsKey == key, let cached = dailyNutritionTargets {
            return cached
        }
        return DietPlanner.targets(profile: profile)
    }

    func nutritionTargets(for date: Date) -> NutritionTargets {
        let key = FitnessDate.key(date)
        if let cached = nutritionTargetsByDate[key] {
            return cached
        }
        return DietPlanner.targets(profile: profile)
    }

    func cacheNutritionTargets(_ targets: NutritionTargets, for date: Date) {
        let key = FitnessDate.key(date)
        nutritionTargetsByDate[key] = targets
        if key == FitnessDate.key(Date()) {
            dailyNutritionTargets = targets
            dailyNutritionTargetsKey = key
        }
        persist()
    }

    /// Profile/body/plan changes can alter every date's target. Drop the
    /// persisted per-date cache so visible screens re-fetch instead of showing
    /// yesterday's formula until the next app launch.
    func invalidateNutritionTargetCaches() {
        nutritionTargetsByDate.removeAll()
        dailyNutritionTargets = nil
        dailyNutritionTargetsKey = nil
    }

    func addCustomFood(_ food: FoodItem) {
        customFoods.removeAll { $0.name == food.name }
        customFoods.insert(food, at: 0)
        persist()
        Task { @MainActor in await self.syncCloudExtras() }
    }

    func isFavoriteFood(_ food: FoodItem) -> Bool {
        favoriteFoods.contains { $0.name == food.name }
    }

    func toggleFavoriteFood(_ food: FoodItem) {
        let key = favoriteKey(for: food)
        if isFavoriteFood(food) {
            favoriteFoods.removeAll { $0.name == food.name }
            removedFavoriteKeys.insert(key)
        } else {
            favoriteFoods.removeAll { $0.name == food.name }
            favoriteFoods.insert(food, at: 0)
            removedFavoriteKeys.remove(key)
        }
        persist()
        Task { @MainActor in await self.syncCloudExtras() }
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

    /// Refresh the server-confirmed target for a concrete date. Any date is
    /// cached, so the plan page, nutrition page and coach cards agree.
    @MainActor
    func refreshNutritionTargets(for date: Date = Date()) async {
        guard AuthTokenStore.shared.accessToken != nil else { return }
        let key = FitnessDate.key(date)
        guard let response = try? await NutritionService().fetchTargets(
            dateString: key
        ), let targets = NutritionTargets(
            remote: response.targets,
            profile: profile
        ) else { return }
        cacheNutritionTargets(targets, for: date)
    }

    /// One-tap planned-meal logging shared by the nutrition page and the coach
    /// diet card. Duplicate checks live here so every entry point behaves the same.
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

    func mergeRemoteFoodLogs(_ items: [RemoteFoodLog]) {
        let service = NutritionService()
        let pendingDeletes = Set(pendingFoodDeletionIDs)
        let pendingUpdates = Set(pendingFoodUpdateIDs)
        for item in items {
            guard !pendingDeletes.contains(item.clientID),
                  !pendingUpdates.contains(item.clientID),
                  let value = service.makeFoodLog(from: item) else {
                continue
            }
            if let index = foodLogs.firstIndex(where: { $0.id == value.id }) {
                foodLogs[index] = value
            } else {
                foodLogs.append(value)
            }
        }
        foodLogs.sort { $0.date > $1.date }
        persist()
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
        dataDidChange(.foodLog, refreshReview: false)
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
        dataDidChange(.foodLog, refreshReview: false)
    }
}
