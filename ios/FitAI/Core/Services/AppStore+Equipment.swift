import Foundation

extension AppStore {
    // MARK: - Equipment

    func addEquipment(_ item: EquipmentItem) {
        equipmentLibrary.insert(item, at: 0)
        persist()
        syncPendingUserData()
    }

    /// 批量把动作加入器械库，自动跳过已存在的动作，返回真正新增的数量。
    @discardableResult
    func addExercisesToEquipmentLibrary(
        _ exercises: [Exercise],
        note: String = "从已选动作加入"
    ) -> Int {
        var existingSlugs = Set(equipmentLibrary.compactMap(\.slug))
        let items = exercises.compactMap { exercise -> EquipmentItem? in
            guard !existingSlugs.contains(exercise.slug) else { return nil }
            existingSlugs.insert(exercise.slug)
            return EquipmentItem(
                name: exercise.nameZH,
                slug: exercise.slug,
                muscle: exercise.muscle,
                equipment: exercise.equipment,
                videoURL: exercise.videoURL?.absoluteString,
                notes: note
            )
        }
        guard !items.isEmpty else { return 0 }
        equipmentLibrary.insert(contentsOf: items, at: 0)
        persist()
        syncPendingUserData()
        return items.count
    }

    func removeEquipment(_ id: UUID) {
        equipmentLibrary.removeAll { $0.id == id }
        persist()
        Task {
            try? await APIClient.shared.deleteEquipmentItem(id: id)
        }
    }
}
