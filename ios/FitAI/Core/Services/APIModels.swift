import Foundation

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
    let env: String?
    let llm: String?
    let vision: String?
    let meituan: String?
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

    let candidates: [Candidate]
    let description: String?
    let name: String?
    let notInLibrary: Bool?

    enum CodingKeys: String, CodingKey {
        case candidates
        case description
        case name
        case notInLibrary = "not_in_library"
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

struct MeituanLinkResponse: Decodable {
    let deeplink: String?
    let h5URL: String?

    enum CodingKeys: String, CodingKey {
        case deeplink
        case h5URL = "h5_url"
    }
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

        enum CodingKeys: String, CodingKey {
            case name
            case grams
            case kcalPer100g = "kcal_per_100g"
            case proteinPer100g = "protein_per_100g"
            case carbsPer100g = "carbs_per_100g"
            case fatPer100g = "fat_per_100g"
            case fiberPer100g = "fiber_per_100g"
            case confidence
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

        enum CodingKeys: String, CodingKey {
            case title
            case weeklyDays = "weekly_days"
            case weekdays
            case sessionMinutes = "session_minutes"
            case weeks
            case dayCount = "day_count"
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

struct AgentActionPayload: Codable, Hashable {
    let dayID: String?
    let date: String?
    let targetDate: String?
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

    enum CodingKeys: String, CodingKey {
        case dayID = "day_id"
        case date
        case targetDate = "target_date"
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
    }
}

struct AgentAction: Codable, Identifiable, Hashable {
    let id: String
    let type: String
    let title: String
    let summary: String
    let requiresConfirmation: Bool
    let payload: AgentActionPayload?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case summary
        case requiresConfirmation = "requires_confirmation"
        case payload
    }
}

struct AgentChatResponse: Decodable {
    let sessionID: UUID?
    let runID: String
    let status: String
    let reply: String
    let proposal: AgentPlanProposal?
    let actions: [AgentAction]?
    let safetyFlag: String?
    let elapsedMS: Int?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case runID = "run_id"
        case status
        case reply
        case proposal
        case actions
        case safetyFlag = "safety_flag"
        case elapsedMS = "elapsed_ms"
    }
}

struct AgentApplyResponse: Decodable {
    let program: TrainingPlan
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
    }
}

struct RemoteFoodLogResponse: Decodable {
    let items: [RemoteFoodLog]
}

struct RemoteBodyMetric: Decodable {
    let clientID: String
    let measuredAt: Date
    let weightKG: Double
    let bodyFatPCT: Double
    let waistCM: Double
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
    let slug: String?
    let muscle: String?
    let equipment: String?
    let notes: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case name
        case slug
        case muscle
        case equipment
        case notes
        case createdAt = "created_at"
    }
}

struct RemoteEquipmentItemResponse: Decodable {
    let items: [RemoteEquipmentItem]
}
struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct WorkoutCreateResponse: Decodable {
    let id: String
}
