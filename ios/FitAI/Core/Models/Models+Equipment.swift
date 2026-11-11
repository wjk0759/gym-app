import Foundation

// MARK: - 器械库与体型分析

struct EquipmentItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// 94 类器械目录 slug（smith_machine / leg_press / dumbbell / treadmill ...）
    var equipmentType: String? = nil
    /// 由 equipmentType 派生的大类（machine / cable / free_weight / cardio ...）
    var category: String? = nil
    var photoURL: String? = nil
    /// 这件器械当前启用的动作 slug（固定器械用；通用器械不用）。
    var enabledExerciseSlugs: [String]? = nil
    var slug: String? = nil
    var muscle: MuscleGroup? = nil
    var equipment: Equipment? = nil
    var videoURL: String? = nil
    var notes: String = ""
    var photoData: Data?
    var createdAt: Date = Date()
    var syncedAt: Date? = nil
    var source: String? = nil
    /// 自定义器械的训练细分部位（二级部位中文名，例如 ["胸大肌", "下胸"]）。
    var targetMuscles: [String]? = nil

    var exercise: Exercise? {
        slug.flatMap { ExerciseLibrary.exercise(slug: $0) }
    }

    var targetMuscleList: [String] {
        targetMuscles ?? []
    }

    /// 按一级部位分组展示：胸 · 胸大肌、下胸 / 背 · 背阔肌。
    var targetMuscleSummary: String? {
        Self.muscleSummary(for: targetMuscleList)
    }

    static func muscleSummary(for values: [String]) -> String? {
        let selected = Set(values)
        guard !selected.isEmpty else { return nil }
        let groups = ExerciseLibrary.categoryTree.compactMap { entry -> String? in
            let matches = entry.l2.filter { selected.contains($0) }
            guard !matches.isEmpty else { return nil }
            return "\(entry.l1) · \(matches.joined(separator: "、"))"
        }
        return groups.isEmpty ? values.joined(separator: "、") : groups.joined(separator: " / ")
    }

    /// 这件器械能练的动作（优先使用目录里显式给出的动作）。
    var trainableExercises: [Exercise] {
        if let type = EquipmentCatalog.type(for: equipmentType) {
            return type.trainableExercises
        }
        guard let group = EquipmentCatalog.group(for: equipmentType) else { return [] }
        return ExerciseLibrary.all.filter { $0.equipmentTypes.contains(group) }
    }
}

struct BodyAnalysis: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var summary: String
    var focusAreas: [MuscleGroup]
    var recommendations: [String]
    var confidence: Double
    var disclaimer: String
    var appliedToPlan: Bool = false
}
