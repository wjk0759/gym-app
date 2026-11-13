import Foundation

struct AvatarResponse: Decodable {
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case avatarURL = "avatar_url"
    }
}

struct RemoteWorkoutSet: Decodable {
    let slug: String
    let setIndex: Int
    let weightKG: Double?
    let reps: Int?
    let rpe: Double?
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case slug
        case setIndex = "set_index"
        case weightKG = "weight_kg"
        case reps
        case rpe
        case completed
    }
}

struct RemoteWorkout: Decodable {
    let id: String
    let clientID: String?
    let programDayID: String?
    let startedAt: Date
    let finishedAt: Date?
    let durationMin: Int?
    let feeling: Int?
    let notes: String?
    let sets: [RemoteWorkoutSet]

    enum CodingKeys: String, CodingKey {
        case id
        case clientID = "client_id"
        case programDayID = "program_day_id"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case durationMin = "duration_min"
        case feeling
        case notes
        case sets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        clientID = try container.decodeIfPresent(String.self, forKey: .clientID)
        programDayID = try container.decodeIfPresent(String.self, forKey: .programDayID)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        durationMin = try container.decodeIfPresent(Int.self, forKey: .durationMin)
        feeling = try container.decodeIfPresent(Int.self, forKey: .feeling)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        sets = try container.decodeIfPresent([RemoteWorkoutSet].self, forKey: .sets) ?? []
    }
}

struct RemoteWorkoutList: Decodable {
    let items: [RemoteWorkout]
}

struct RemoteScheduleDay: Decodable {
    let dayID: String
    let assignedDate: String?
    let skippedAt: Date?
    let clientUpdatedAt: Date?
    let serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case dayID = "day_id"
        case assignedDate = "assigned_date"
        case skippedAt = "skipped_at"
        case clientUpdatedAt = "client_updated_at"
        case serverUpdatedAt = "server_updated_at"
    }
}

struct RemoteScheduleState: Decodable {
    let planID: String
    let days: [RemoteScheduleDay]

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case days
    }
}

struct PlanScheduleUploadDay: Encodable {
    let dayID: String
    let assignedDate: String?
    let skippedAt: Date?
    let clientUpdatedAt: Date

    enum CodingKeys: String, CodingKey {
        case dayID = "day_id"
        case assignedDate = "assigned_date"
        case skippedAt = "skipped_at"
        case clientUpdatedAt = "client_updated_at"
    }
}

struct HealthStatus: Decodable {
    let status: String?
    let llm: String?
}

struct ChatResponse: Decodable {
    let sessionID: UUID?
    let reply: String
    let safetyFlag: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case reply
        case safetyFlag = "safety_flag"
    }
}

struct EquipmentScanResponse: Decodable {
    struct Candidate: Decodable {
        let slug: String
        let confidence: Double
    }

    struct EquipmentOption: Decodable {
        let slug: String
        let nameZh: String
        let confidence: Double
        let candidates: [Candidate]

        enum CodingKeys: String, CodingKey {
            case slug
            case nameZh = "name_zh"
            case confidence
            case candidates
        }
    }

    let candidates: [Candidate]
    let description: String?
    let name: String?
    let notInLibrary: Bool?
    let warning: String?
    let status: String?
    let equipmentSlug: String?
    let equipmentName: String?
    let confidence: Double?
    let equipmentCandidates: [EquipmentOption]?

    enum CodingKeys: String, CodingKey {
        case candidates
        case description
        case name
        case notInLibrary = "not_in_library"
        case warning
        case status
        case equipmentSlug = "equipment_slug"
        case equipmentName = "equipment_name"
        case confidence
        case equipmentCandidates = "equipment_candidates"
    }
}

struct ExerciseVideoResponse: Decodable {
    struct Video: Decodable {
        let videoURL: String?

        enum CodingKeys: String, CodingKey {
            case videoURL = "video_url"
        }
    }

    let video: Video?
}

struct BodyAnalysisResponse: Decodable {
    let summary: String
    let focusAreas: [String]
    let recommendations: [String]
    let confidence: Double
    let disclaimer: String

    enum CodingKeys: String, CodingKey {
        case summary
        case focusAreas = "focus_areas"
        case recommendations
        case confidence
        case disclaimer
    }
}

struct FoodAnalysisResponse: Decodable {
    struct Item: Decodable {
        let name: String
        let grams: Double
        let kcalPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let fiberPer100g: Double?
        let confidence: Double
        let gramsMin: Double?
        let gramsMax: Double?
        let portionConfidence: Double?
        let portionBasis: String?

        enum CodingKeys: String, CodingKey {
            case name
            case grams
            case kcalPer100g = "kcal_per_100g"
            case proteinPer100g = "protein_per_100g"
            case carbsPer100g = "carbs_per_100g"
            case fatPer100g = "fat_per_100g"
            case fiberPer100g = "fiber_per_100g"
            case confidence
            case gramsMin = "grams_min"
            case gramsMax = "grams_max"
            case portionConfidence = "portion_confidence"
            case portionBasis = "portion_basis"
        }
    }

    let items: [Item]
    let confidence: Double
    let disclaimer: String
    let model: String?
    let summary: String?
    let isFood: Bool?

    enum CodingKeys: String, CodingKey {
        case items
        case confidence
        case disclaimer
        case model
        case summary
        case isFood = "is_food"
    }
}

struct AgentProposalDiff: Codable, Hashable {
    struct Proposed: Codable, Hashable {
        let title: String?
        let weeklyDays: Int?
        let weekdays: [Int]?
        let sessionMinutes: Int?
        let weeks: Int?
        let dayCount: Int?
        let focus: [String]?

        enum CodingKeys: String, CodingKey {
            case title
            case weeklyDays = "weekly_days"
            case weekdays
            case sessionMinutes = "session_minutes"
            case weeks
            case dayCount = "day_count"
            case focus
        }
    }

    let changes: [String]
    let proposed: Proposed?

    enum CodingKeys: String, CodingKey {
        case changes
        case proposed
    }
}

struct AgentPlanProposal: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let changes: [String]
    let diff: AgentProposalDiff?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case changes
        case diff
        case expiresAt = "expires_at"
    }

    var proposed: AgentProposalDiff.Proposed? { diff?.proposed }
}

struct AgentWorkoutChange: Codable, Hashable {
    let op: String
    let fromSlug: String?
    let toSlug: String?
    let slug: String?
    let sets: Int?
    let reps: String?
    let weightKG: Double?
    let restSec: Int?

    enum CodingKeys: String, CodingKey {
        case op
        case fromSlug = "from_slug"
        case toSlug = "to_slug"
        case slug
        case sets
        case reps
        case weightKG = "weight_kg"
        case restSec = "rest_sec"
    }
}

struct AgentFoodItem: Codable, Hashable {
    let name: String
    let portion: String?
    let grams: Double
    let kcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case portion
        case grams
        case kcal
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case confidence
    }
}

struct AgentLoggedSet: Codable, Hashable {
    let slug: String
    let setIndex: Int?
    let weightKG: Double?
    let reps: Int?
    let rpe: Double?
    let completed: Bool?

    enum CodingKeys: String, CodingKey {
        case slug
        case setIndex = "set_index"
        case weightKG = "weight_kg"
        case reps
        case rpe
        case completed
    }
}

struct AgentActionPayload: Codable, Hashable {
    let dayID: String?
    var date: String?
    let targetDate: String?
    let clientID: String?
    let screen: String?
    let goalType: String?
    let targetWeightKG: Double?
    let weeklyDays: Int?
    let sessionMinutes: Int?
    let weightKG: Double?
    let bodyFatPCT: Double?
    let waistCM: Double?
    let strategy: String?
    let weekStart: String?
    var meal: String?
    let rawText: String?
    var items: [AgentFoodItem]?
    let title: String?
    let durationMinutes: Int?
    let kind: String?
    let notes: String?
    let programDayID: String?
    let sessionID: String?
    let sets: [AgentLoggedSet]?
    let scope: String?
    let changes: [AgentWorkoutChange]?

    enum CodingKeys: String, CodingKey {
        case dayID = "day_id"
        case date
        case targetDate = "target_date"
        case clientID = "client_id"
        case screen
        case goalType = "goal_type"
        case targetWeightKG = "target_weight_kg"
        case weeklyDays = "weekly_days"
        case sessionMinutes = "session_minutes"
        case weightKG = "weight_kg"
        case bodyFatPCT = "body_fat_pct"
        case waistCM = "waist_cm"
        case strategy
        case weekStart = "week_start"
        case meal
        case rawText = "raw_text"
        case items
        case title
        case durationMinutes = "duration_minutes"
        case kind
        case notes
        case programDayID = "program_day_id"
        case sessionID = "session_id"
        case sets
        case scope
        case changes
    }
}

struct AgentAction: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    var summary: String
    let requiresConfirmation: Bool
    var payload: AgentActionPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case summary
        case requiresConfirmation = "requires_confirmation"
        case payload
    }
}

struct AgentPendingDraft: Decodable, Identifiable, Hashable {
    let id: String
    let type: String
    let summary: String
    let questions: [String]?
}

struct AgentChatResponse: Decodable {
    let sessionID: UUID?
    let messageID: String?
    let runID: String
    let status: String
    let reply: String
    let proposal: AgentPlanProposal?
    let actions: [AgentAction]?
    let pendingDraft: AgentPendingDraft?
    let safetyFlag: String?
    let elapsedMS: Int?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case messageID = "message_id"
        case runID = "run_id"
        case status
        case reply
        case proposal
        case actions
        case pendingDraft = "pending_draft"
        case safetyFlag = "safety_flag"
        case elapsedMS = "elapsed_ms"
    }
}

struct AgentApplyResponse: Decodable {
    let program: TrainingPlan
}

struct AgentActionRunRequest: Encodable {
    let type: String
    let payload: AgentActionPayload
}

struct AgentActionRunResponse: Decodable {
    let status: String
    let type: String?
    let result: AgentActionRunResult?
}

struct AgentActionRunResult: Decodable {
    let groupID: String?
    let createdLogs: [RemoteFoodLog]?
    let updatedLog: RemoteFoodLog?
    let deletedLog: RemoteFoodLog?

    enum CodingKeys: String, CodingKey {
        case groupID = "group_id"
        case createdLogs = "created_logs"
        case updatedLog = "updated_log"
        case deletedLog = "deleted_log"
    }
}

struct WorkoutActionExecuteResponse: Decodable {
    let program: TrainingPlan
    let actionID: String
    let status: String
    let idempotent: Bool?

    enum CodingKeys: String, CodingKey {
        case program
        case actionID = "action_id"
        case status
        case idempotent
    }
}

struct AgentMemory: Codable, Identifiable, Hashable {
    let id: String
    let kind: String
    let key: String
    let content: String
    let source: String
    let confidence: Double
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case key
        case content
        case source
        case confidence
        case updatedAt = "updated_at"
    }
}

struct AgentMemoryResponse: Decodable {
    let items: [AgentMemory]
}

struct AgentReviewStats: Codable, Hashable {
    let sessions: Int
    let planned: Int
    let completionRate: Double
    let volumeKG: Double
    let averageRPE: Double?
    let averageDurationMin: Int
    let previousVolumeKG: Double
    let nutritionLoggedDays: Int
    let planTitle: String?
    let plannedDays: Int?
    let completedPlanDays: Int?
    let skippedPlanDays: Int?
    let missedPlanDays: Int?
    let adherenceRate: Double?
    let dietPlannedMeals: Int?
    let dietLoggedPlanMeals: Int?
    let dietAdherenceRate: Double?
    let dietPlannedKcal: Int?
    let dietActualKcal: Int?

    enum CodingKeys: String, CodingKey {
        case sessions
        case planned
        case completionRate = "completion_rate"
        case volumeKG = "volume_kg"
        case averageRPE = "average_rpe"
        case averageDurationMin = "average_duration_min"
        case previousVolumeKG = "previous_volume_kg"
        case nutritionLoggedDays = "nutrition_logged_days"
        case planTitle = "plan_title"
        case plannedDays = "planned_days"
        case completedPlanDays = "completed_plan_days"
        case skippedPlanDays = "skipped_plan_days"
        case missedPlanDays = "missed_plan_days"
        case adherenceRate = "adherence_rate"
        case dietPlannedMeals = "diet_planned_meals"
        case dietLoggedPlanMeals = "diet_logged_plan_meals"
        case dietAdherenceRate = "diet_adherence_rate"
        case dietPlannedKcal = "diet_planned_kcal"
        case dietActualKcal = "diet_actual_kcal"
    }
}

struct AgentWeeklyReview: Codable, Hashable, Identifiable {
    let runID: String
    let period: String
    let weekStart: String
    let stats: AgentReviewStats
    let summary: String
    let wins: [String]
    let watchouts: [String]
    let actions: [String]
    let generatedAt: Date

    var id: String { runID }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case period
        case weekStart = "week_start"
        case stats
        case summary
        case wins
        case watchouts
        case actions
        case generatedAt = "generated_at"
    }
}

struct RemoteFoodLog: Decodable {
    let clientID: String
    let loggedAt: Date
    let meal: String
    let foodName: String
    let grams: Double
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let planDate: Date?
    let planMeal: String?
    let sourceActionID: String?
    let sourceGroupID: String?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case loggedAt = "logged_at"
        case meal
        case foodName = "food_name"
        case grams
        case kcal
        case protein
        case carbs
        case fat
        case fiber
        case planDate = "plan_date"
        case planMeal = "plan_meal"
        case sourceActionID = "source_action_id"
        case sourceGroupID = "source_group_id"
    }
}

struct RemoteFoodLogResponse: Decodable {
    let items: [RemoteFoodLog]
}

struct RemoteBodyMetric: Decodable {
    let clientID: String
    let measuredAt: Date
    let weightKG: Double?
    let bodyFatPCT: Double?
    let waistCM: Double?
    let armCM: Double?
    let thighCM: Double?

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case measuredAt = "measured_at"
        case weightKG = "weight_kg"
        case bodyFatPCT = "body_fat_pct"
        case waistCM = "waist_cm"
        case armCM = "arm_cm"
        case thighCM = "thigh_cm"
    }
}

struct RemoteBodyMetricResponse: Decodable {
    let items: [RemoteBodyMetric]
}

struct RemoteEquipmentItem: Decodable {
    let clientID: String
    let name: String
    let equipmentType: String?
    let category: String?
    let photoURL: String?
    let enabledExerciseSlugs: [String]?
    let slug: String?
    let muscle: String?
    let equipment: String?
    let targetMuscles: [String]?
    let notes: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case name
        case equipmentType = "equipment_type"
        case category
        case photoURL = "photo_url"
        case enabledExerciseSlugs = "enabled_exercise_slugs"
        case slug
        case muscle
        case equipment
        case targetMuscles = "target_muscles"
        case notes
        case createdAt = "created_at"
    }
}

struct RemoteEquipmentItemResponse: Decodable {
    let items: [RemoteEquipmentItem]
}

struct EquipmentPhotoResponse: Decodable {
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
    }
}

struct RemoteUniversalEquipmentItem: Decodable {
    let slug: String
    let nameZH: String
    let enabled: Bool

    enum CodingKeys: String, CodingKey {
        case slug
        case nameZH = "name_zh"
        case enabled
    }
}

struct RemoteUniversalEquipmentResponse: Decodable {
    let items: [RemoteUniversalEquipmentItem]
}
struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct WorkoutCreateResponse: Decodable {
    let id: String
}
