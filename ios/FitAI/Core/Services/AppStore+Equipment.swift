import Foundation

extension AppStore {
    // MARK: - 计划池

    /// 所有固定器械启用的动作并集（去重）。
    var enabledExerciseSlugs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in equipmentLibrary {
            for slug in (item.enabledExerciseSlugs ?? []) where seen.insert(slug).inserted {
                result.append(slug)
            }
        }
        return result
    }

    /// 计划池 = 固定器械启用动作 + 已勾选通用器械的动作（去重）。
    var planPoolSlugs: [String] {
        var seen = Set(enabledExerciseSlugs)
        var result = enabledExerciseSlugs
        for group in selectedUniversalSlugs {
            for exercise in ExerciseLibrary.universalExercises[group] ?? [] {
                if seen.insert(exercise.slug).inserted {
                    result.append(exercise.slug)
                }
            }
        }
        return result
    }

    /// 计划池覆盖的部位。
    var planPoolBodyParts: Set<String> {
        Set(planPoolSlugs.compactMap { ExerciseLibrary.exercise(slug: $0)?.bodyPart })
    }

    // MARK: - 器械库（物理器械）

    func addEquipment(_ item: EquipmentItem) {
        equipmentLibrary.insert(item, at: 0)
        persist()
        syncPendingUserData()
    }

    /// 保存一件物理器械（拍照识别结果或手动添加）。
    @discardableResult
    func addEquipment(
        equipmentType: String?,
        name: String,
        category: String? = nil,
        photoData: Data? = nil,
        enabledExerciseSlugs: [String] = [],
        notes: String = "",
        source: String = "manual"
    ) -> EquipmentItem {
        let item = EquipmentItem(
            name: name,
            equipmentType: equipmentType,
            category: category,
            photoURL: nil,
            enabledExerciseSlugs: enabledExerciseSlugs,
            slug: nil,
            muscle: nil,
            equipment: nil,
            videoURL: nil,
            notes: notes,
            photoData: photoData,
            source: source
        )
        equipmentLibrary.insert(item, at: 0)
        persist()
        syncPendingUserData()
        return item
    }

    func removeEquipment(_ id: UUID) {
        equipmentLibrary.removeAll { $0.id == id }
        persist()
        Task {
            try? await APIClient.shared.deleteEquipmentItem(id: id)
        }
    }

    // MARK: - 固定器械动作选择

    func toggleEquipmentExercise(_ itemID: UUID, slug: String) {
        guard let index = equipmentLibrary.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        var slugs = equipmentLibrary[index].enabledExerciseSlugs ?? []
        if let pos = slugs.firstIndex(of: slug) {
            slugs.remove(at: pos)
        } else {
            slugs.append(slug)
        }
        equipmentLibrary[index].enabledExerciseSlugs = slugs
        equipmentLibrary[index].syncedAt = nil
        persist()
        syncPendingUserData()
    }

    func replaceEquipmentExercises(_ itemID: UUID, slugs: [String]) {
        guard let index = equipmentLibrary.firstIndex(where: { $0.id == itemID }) else {
            return
        }
        equipmentLibrary[index].enabledExerciseSlugs = slugs
        equipmentLibrary[index].syncedAt = nil
        persist()
        syncPendingUserData()
    }

    // MARK: - 通用器械勾选

    func setUniversalEquipment(_ slugs: [String]) {
        selectedUniversalSlugs = slugs
        persist()
        Task {
            try? await APIClient.shared.replaceUniversalEquipment(slugs: slugs)
        }
    }

    func toggleUniversalEquipment(_ slug: String) {
        var slugs = selectedUniversalSlugs
        if let pos = slugs.firstIndex(of: slug) {
            slugs.remove(at: pos)
        } else {
            slugs.append(slug)
        }
        setUniversalEquipment(slugs)
    }
}
