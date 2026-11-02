import Foundation

// MARK: - 器械库与体型分析

struct EquipmentItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var slug: String?
    var muscle: MuscleGroup?
    var equipment: Equipment?
    var videoURL: String?
    var notes: String = ""
    var photoData: Data?
    var createdAt: Date = Date()
    var syncedAt: Date? = nil
    var source: String? = nil

    var exercise: Exercise? {
        slug.flatMap { ExerciseLibrary.exercise(slug: $0) }
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
