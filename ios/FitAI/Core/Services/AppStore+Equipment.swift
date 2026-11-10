import Foundation

extension AppStore {
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
        source: String = "manual"
    ) -> EquipmentItem {
        let item = EquipmentItem(
            name: name,
            equipmentType: equipmentType,
            category: category,
            photoURL: nil,
            slug: nil,
            muscle: nil,
            equipment: nil,
            videoURL: nil,
            notes: "",
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

    // MARK: - 个人动作库

    /// 把动作加入个人动作库（默认全选器械可练动作后调用）。
    @discardableResult
    func addExercisesToPersonalLibrary(
        _ exercises: [Exercise],
        equipmentType: String? = nil
    ) -> Int {
        var existing = Set(personalExerciseSlugs)
        var added = 0
        for exercise in exercises where !existing.contains(exercise.slug) {
            personalExerciseSlugs.append(exercise.slug)
            existing.insert(exercise.slug)
            added += 1
        }
        guard added > 0 else { return 0 }
        persist()
        Task {
            try? await APIClient.shared.addExerciseLibrary(
                slugs: exercises.map(\.slug),
                equipmentType: equipmentType
            )
        }
        return added
    }

    func removeFromPersonalLibrary(_ slug: String) {
        personalExerciseSlugs.removeAll { $0 == slug }
        persist()
        Task {
            try? await APIClient.shared.deleteExerciseLibrary(slug: slug)
        }
    }

    /// 兼容旧调用：原来「加入器械库」实际是收藏动作，现在转成个人动作库。
    @discardableResult
    func addExercisesToEquipmentLibrary(
        _ exercises: [Exercise],
        note: String = ""
    ) -> Int {
        addExercisesToPersonalLibrary(exercises)
    }
}
