import Foundation

/// 可复用偏好（收藏/自定义食物/动作偏好/周期设置）的云同步。
/// 数据量小，使用全量快照而不是游标；冲突按服务端时间/集合合并。
extension AppStore {
    /// Push reusable food/exercise data and durable preferences, then merge
    /// anything another device added. Collections are small, so the first
    /// implementation uses a full snapshot rather than a cursor.
    @MainActor
    func syncCloudExtras() async {
        guard AuthTokenStore.shared.accessToken != nil, !isSyncingCloudExtras else {
            return
        }
        isSyncingCloudExtras = true
        defer { isSyncingCloudExtras = false }

        do {
            let remote = try await APIClient.shared.fetchCloudSync()
            mergeCloudSnapshot(remote)
            let payload = cloudPushPayload()
            let updated = try await APIClient.shared.pushCloudSync(payload)
            mergeCloudSnapshot(updated)
            removedFavoriteKeys.removeAll()
            removedDislikedSlugs.removeAll()
            preferencesDirty = false
            cycleDirty = false
            persist()
            await refreshNotificationDeviceState()
        } catch {
            // Keep local state and retry on the next foreground/login sync.
        }
    }

    func markPreferencesDirty() {
        preferencesDirty = true
        persist()
        Task { @MainActor in
            await self.syncCloudExtras()
        }
    }

    func setUseRemoteAI(_ enabled: Bool) {
        guard useRemoteAI != enabled else { return }
        useRemoteAI = enabled
        markPreferencesDirty()
    }

    func setStrictEquipmentMode(_ enabled: Bool) {
        guard strictEquipmentMode != enabled else { return }
        strictEquipmentMode = enabled
        noteEquipmentMutation()
        markPreferencesDirty()
    }

    private func mergeCloudSnapshot(_ remote: RemoteCloudSync) {
        if let preferences = remote.preferences, !preferencesDirty {
            if let value = preferences.strictEquipmentMode {
                strictEquipmentMode = value
            }
            if let value = preferences.useRemoteAI {
                useRemoteAI = value
            }
            if let value = preferences.reminderHour {
                reminderHour = value
            }
            if let value = preferences.reminderMinute {
                reminderMinute = value
            }
            if let value = preferences.notificationsEnabled {
                // `notifications_enabled` stores account intent, not whether
                // this particular device can post notifications.
                remindersEnabled = value
            }
            if let value = preferences.proactiveEnabled {
                proactiveCoachEnabled = value
            }
            if let raw = preferences.bodyCheckinFrequency,
               let frequency = BodyCheckInFrequency(rawValue: raw) {
                bodyCheckInFrequency = frequency
            }
            if let value = preferences.bodyCheckinWeekday {
                bodyCheckInWeekday = value
            }
            if let value = preferences.bodyCheckinDay {
                bodyCheckInDay = value
            }
        }

        if let cycle = remote.cycle, !cycleDirty {
            profile.periodRangeStart = cycle.rangeStart
            profile.periodRangeEnd = cycle.rangeEnd
            profile.periodDates = cycle.dates
            if let raw = cycle.trainingMode,
               let mode = PeriodTrainingMode(rawValue: raw) {
                profile.periodTrainingMode = mode
            }
        }

        let normalized = normalizedCustomFoods()
        for item in remote.customFoods {
            guard let id = UUID(uuidString: item.clientID) else { continue }
            guard !normalized.contains(where: { $0.clientID == id }) else {
                continue
            }
            guard !customFoods.contains(where: { $0.name == item.name }) else {
                continue
            }
            customFoods.insert(
                FoodItem(
                    name: item.name,
                    category: item.category ?? "自定义",
                    kcal: item.kcal ?? 0,
                    protein: item.protein ?? 0,
                    carbs: item.carbs ?? 0,
                    fat: item.fat ?? 0,
                    fiber: item.fiber,
                    defaultGrams: item.defaultGrams,
                    clientID: id
                ),
                at: 0
            )
        }

        for item in remote.favorites {
            if removedFavoriteKeys.contains(item.foodKey) {
                continue
            }
            guard let food = favoriteFood(for: item) else { continue }
            guard !favoriteFoods.contains(where: { $0.name == food.name }) else {
                continue
            }
            favoriteFoods.append(food)
        }

        for item in remote.dislikedExercises {
            if removedDislikedSlugs.contains(item.slug) {
                continue
            }
            dislikedSlugs.insert(item.slug)
        }

        persist()
    }

    private func favoriteFood(for item: RemoteCloudFavorite) -> FoodItem? {
        if item.foodKey.hasPrefix("custom:") {
            let raw = String(item.foodKey.dropFirst("custom:".count))
            if let id = UUID(uuidString: raw),
               let food = customFoods.first(where: { $0.clientID == id }) {
                return food
            }
        }
        if let food = customFoods.first(where: { $0.name == item.name }) {
            return food
        }
        return FoodLibrary.all.first(where: { $0.name == item.name })
    }

    private func normalizedCustomFoods() -> [FoodItem] {
        var items = customFoods
        var changed = false
        for index in items.indices where items[index].clientID == nil {
            items[index].clientID = UUID()
            changed = true
        }
        if changed {
            customFoods = items
        }
        return items
    }

    func favoriteKey(for food: FoodItem) -> String {
        if let customIndex = customFoods.firstIndex(where: { $0.name == food.name }) {
            if customFoods[customIndex].clientID == nil {
                customFoods[customIndex].clientID = UUID()
                persist()
            }
            if let id = customFoods[customIndex].clientID {
                return "custom:" + id.uuidString.lowercased()
            }
        }
        if let id = food.clientID {
            return "custom:" + id.uuidString.lowercased()
        }
        return "library:" + food.name
    }

    private func cloudPushPayload() -> [String: Any] {
        let foods = normalizedCustomFoods()
        let favorites: [[String: Any]] = favoriteFoods.map { food -> [String: Any] in
            [
                "food_key": favoriteKey(for: food),
                "name": food.name,
            ]
        } + removedFavoriteKeys.map { key -> [String: Any] in
            [
                "food_key": key,
                "name": "已删除",
                "deleted": true,
            ]
        }
        let dislikes: [[String: Any]] = dislikedSlugs.sorted().map { slug -> [String: Any] in
            ["slug": slug]
        } + removedDislikedSlugs.sorted().map { slug -> [String: Any] in
            ["slug": slug, "deleted": true]
        }
        var payload: [String: Any] = [
            "custom_foods": foods.compactMap { food -> [String: Any]? in
                guard let id = food.clientID else { return nil }
                var item: [String: Any] = [
                    "client_id": id.uuidString.lowercased(),
                    "name": food.name,
                    "category": food.category,
                    "kcal": food.kcal,
                    "protein": food.protein,
                    "carbs": food.carbs,
                    "fat": food.fat,
                ]
                if let fiber = food.fiber {
                    item["fiber"] = fiber
                }
                if let grams = food.defaultGrams {
                    item["default_grams"] = grams
                }
                return item
            },
            "favorites": favorites,
            "disliked_exercises": dislikes,
        ]

        if preferencesDirty {
            payload["preferences"] = [
                "strict_equipment_mode": strictEquipmentMode,
                "use_remote_ai": useRemoteAI,
                "reminder_hour": reminderHour,
                "reminder_minute": reminderMinute,
                "notifications_enabled": remindersEnabled,
                "proactive_enabled": proactiveCoachEnabled,
                "body_checkin_frequency": bodyCheckInFrequency.rawValue,
                "body_checkin_weekday": bodyCheckInWeekday,
                "body_checkin_day": bodyCheckInDay,
            ] as [String: Any]
        }
        if cycleDirty {
            var cycle: [String: Any] = [
                "dates": profile.periodDates,
                "training_mode": profile.periodTrainingMode.rawValue,
            ]
            if let start = profile.periodRangeStart {
                cycle["range_start"] = start
            }
            if let end = profile.periodRangeEnd {
                cycle["range_end"] = end
            }
            payload["cycle"] = cycle
        }
        return payload
    }
}
