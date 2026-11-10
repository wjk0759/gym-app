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
    var slug: String? = nil
    var muscle: MuscleGroup? = nil
    var equipment: Equipment? = nil
    var videoURL: String? = nil
    var notes: String = ""
    var photoData: Data?
    var createdAt: Date = Date()
    var syncedAt: Date? = nil
    var source: String? = nil

    var exercise: Exercise? {
        slug.flatMap { ExerciseLibrary.exercise(slug: $0) }
    }

    /// 这件器械能练的动作（来自全局器械→动作映射，编译进 catalog）。
    var trainableExercises: [Exercise] {
        guard let equipmentType else { return [] }
        return ExerciseLibrary.all.filter { $0.equipmentTypes.contains(equipmentType) }
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
