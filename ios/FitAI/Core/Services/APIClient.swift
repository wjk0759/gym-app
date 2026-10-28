import Foundation

struct APIError: LocalizedError {
    let message: String
    let statusCode: Int?

    init(message: String, statusCode: Int? = nil) {
        self.message = message
        self.statusCode = statusCode
    }

    var errorDescription: String? { message }
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

private struct EquipmentScanResponse: Decodable {
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

private struct ExerciseVideoResponse: Decodable {
    struct Video: Decodable {
        let videoURL: String?

        enum CodingKeys: String, CodingKey {
            case videoURL = "video_url"
        }
    }

    let video: Video?
}

private struct MeituanLinkResponse: Decodable {
    let deeplink: String?
    let h5URL: String?

    enum CodingKeys: String, CodingKey {
        case deeplink
        case h5URL = "h5_url"
    }
}

private struct BodyAnalysisResponse: Decodable {
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

private struct FoodAnalysisResponse: Decodable {
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
    let elapsedMS: Int?

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case runID = "run_id"
        case status
        case reply
        case proposal
        case actions
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
private struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct WorkoutCreateResponse: Decodable {
    let id: String
}

struct APIClient {
    static let shared = APIClient()

    private var baseURL: URL { AppConfig.apiBaseURL }
    private let userID = "00000000-0000-0000-0000-000000000001"

    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let utcDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let naiveDateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"].map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            formatter.dateFormat = format
            return formatter
        }
    }()

    init() {}

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = Self.iso8601WithFractionalSeconds.date(from: text) {
                return date
            }
            if let date = Self.iso8601.date(from: text) {
                return date
            }
            for formatter in Self.naiveDateFormatters {
                if let date = formatter.date(from: text) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期：\(text)"
            )
        }
        return try decoder.decode(type, from: data)
    }

    // MARK: - 档案

    func syncProfile(_ profile: UserProfile) async throws {
        var payload: [String: Any] = [
            "nickname": profile.nickname,
            "sex": profile.sex.rawValue,
            "birth_date": birthDateString(age: profile.age),
            "height_cm": profile.heightCM,
            "weight_kg": profile.weightKG,
            "body_fat_pct": profile.bodyFatPCT,
            "waist_cm": profile.waistCM,
            "chest_cm": profile.chestCM,
            "hip_cm": profile.hipCM,
            "experience": profile.experience.rawValue,
            "equipment": profile.equipment.map(\.rawValue),
            "weekly_days": profile.weeklyDays,
            "session_minutes": profile.sessionMinutes
        ]
        payload["injuries"] = profile.injuries.isEmpty ? [String]() : [profile.injuries]

        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "me/profile", method: "PUT", body: body)
    }

    func syncGoal(_ profile: UserProfile) async throws {
        var payload: [String: Any] = ["type": apiGoalType(profile.goalType)]
        if profile.goalType != .endurance {
            payload["target_weight_kg"] = profile.targetWeightKG
        }
        if let targetWaist = profile.targetWaistCM {
            payload["target_waist_cm"] = targetWaist
        }
        if let targetBodyFat = profile.targetBodyFatPCT {
            payload["target_body_fat_pct"] = targetBodyFat
        }
        payload["target_date"] = Self.birthDateFormatter.string(from: profile.targetDate)
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "me/goal", method: "PUT", body: body)
    }

    // MARK: - 训练记录

    func createWorkout(_ session: WorkoutSession) async throws -> String {
        let finishedAt = session.date
        let startedAt = finishedAt.addingTimeInterval(-Double(max(0, session.durationMinutes) * 60))
        var payload: [String: Any] = [
            "client_id": session.id.uuidString,
            "started_at": Self.iso8601WithFractionalSeconds.string(from: startedAt),
            "finished_at": Self.iso8601WithFractionalSeconds.string(from: finishedAt),
            "feeling": min(5, max(1, session.feeling)),
            "sets": session.sets.map { log in
                var value: [String: Any] = [
                    "slug": log.slug,
                    "set_index": log.setIndex,
                    "weight_kg": log.weightKG,
                    "reps": log.reps,
                    "rpe": log.rpe,
                    "completed": log.completed
                ]
                if log.weightKG <= 0 { value.removeValue(forKey: "weight_kg") }
                return value
            }
        ]
        if let notes = session.notes, !notes.isEmpty {
            payload["notes"] = notes
        }
        if let day = session.programDayID {
            payload["program_day_id"] = day
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: WorkoutCreateResponse = try await send(
            path: "workouts",
            method: "POST",
            body: body
        )
        return response.id
    }

    func updateWorkout(id: String, session: WorkoutSession) async throws {
        let finishedAt = session.date
        let startedAt = finishedAt.addingTimeInterval(-Double(max(0, session.durationMinutes) * 60))
        var payload: [String: Any] = [
            "started_at": Self.iso8601WithFractionalSeconds.string(from: startedAt),
            "finished_at": Self.iso8601WithFractionalSeconds.string(from: finishedAt),
            "feeling": min(5, max(1, session.feeling)),
            "sets": session.sets.map { log in
                var value: [String: Any] = [
                    "slug": log.slug,
                    "set_index": log.setIndex,
                    "weight_kg": log.weightKG,
                    "reps": log.reps,
                    "rpe": log.rpe,
                    "completed": log.completed
                ]
                if log.weightKG <= 0 { value.removeValue(forKey: "weight_kg") }
                return value
            }
        ]
        if let notes = session.notes, !notes.isEmpty {
            payload["notes"] = notes
        }
        if let day = session.programDayID {
            payload["program_day_id"] = day
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(
            path: "workouts/\(id)",
            method: "PATCH",
            body: body
        )
    }

    func deleteWorkout(id: String) async throws {
        try await sendVoid(path: "workouts/\(id)", method: "DELETE", body: nil)
    }

    /// 拉取近 90 天训练记录，用于跨设备恢复历史和补齐服务端产生的修改。
    func fetchRecentWorkouts(days: Int = 90) async throws -> [RemoteWorkout] {
        let from = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -max(1, days),
            to: Date()
        ) ?? Date()
        let text = Self.utcDateFormatter.string(from: from)
        let data = try await perform(
            path: "workouts?from=\(text)&limit=100&include_sets=true",
            method: "GET",
            body: nil
        )
        return try decode(RemoteWorkoutList.self, from: data).items
    }

    // MARK: - 健康检查

    func healthStatus() async throws -> HealthStatus {
        let root = baseURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var request = URLRequest(url: root.appendingPathComponent("health"))
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw APIError(message: "健康检查失败")
        }
        return try decode(HealthStatus.self, from: data)
    }

    func health() async throws -> Bool {
        let status = try await healthStatus()
        return status.status == "ok"
    }

    // MARK: - 计划

    func generatePlan(
        force: Bool = true,
        equipmentSlugs: [String] = [],
        split: SplitType
    ) async throws -> TrainingPlan {
        let body = try JSONSerialization.data(withJSONObject: [
            "force": force,
            "equipment_slugs": equipmentSlugs,
            "split": split.rawValue
        ])
        // AI 计划生成在 DeepSeek reasoning 开启时可能接近 100 秒；
        // 90 秒会先于服务端返回而失败，随后又落回本地模板。
        return try await send(path: "plans/generate", method: "POST", body: body, timeout: 150)
    }

    func fetchSchedule(planID: String) async throws -> RemoteScheduleState {
        let encoded = planID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? planID
        return try await send(
            path: "schedule?plan_id=\(encoded)",
            method: "GET",
            body: nil
        )
    }

    func syncSchedule(
        planID: String,
        planVersion: Int?,
        days: [PlanScheduleUploadDay]
    ) async throws -> RemoteScheduleState {
        struct Payload: Encodable {
            let planID: String
            let planVersion: Int?
            let days: [PlanScheduleUploadDay]

            enum CodingKeys: String, CodingKey {
                case planID = "plan_id"
                case planVersion = "plan_version"
                case days
            }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.iso8601WithFractionalSeconds.string(from: date))
        }
        let body = try encoder.encode(
            Payload(planID: planID, planVersion: planVersion, days: days)
        )
        return try await send(
            path: "schedule",
            method: "PUT",
            body: body
        )
    }

    // MARK: - 对话

    func sendChat(
        message: String,
        sessionID: UUID? = nil,
        skill: CoachSkill = .trainer,
        context: String? = nil
    ) async throws -> ChatResponse {
        var payload: [String: Any] = [
            "message": message,
            "skill": skill.rawValue
        ]
        if let sessionID { payload["session_id"] = sessionID.uuidString }
        if let context { payload["context"] = context }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(path: "coach/chat", method: "POST", body: body, timeout: 50)
    }

    // MARK: - Agent

    func agentChat(
        message: String,
        sessionID: UUID? = nil,
        skill: CoachSkill = .trainer,
        appContext: [String: Any]? = nil,
        requestID: UUID? = nil
    ) async throws -> AgentChatResponse {
        var payload: [String: Any] = [
            "message": message,
            "skill": skill.rawValue
        ]
        if let sessionID { payload["session_id"] = sessionID.uuidString }
        if let appContext { payload["app_context"] = appContext }
        if let requestID { payload["request_id"] = requestID.uuidString }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(path: "agent/chat", method: "POST", body: body, timeout: 50)
    }

    func agentWeeklyReview() async throws -> AgentWeeklyReview {
        try await send(
            path: "agent/reviews/weekly",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: [:])
        )
    }

    func applyAgentProposal(id: String) async throws -> TrainingPlan {
        let response: AgentApplyResponse = try await send(
            path: "agent/proposals/\(id)/apply",
            method: "POST",
            body: nil
        )
        return response.program
    }

    func agentMemories() async throws -> [AgentMemory] {
        let response: AgentMemoryResponse = try await send(
            path: "agent/memories",
            method: "GET",
            body: nil
        )
        return response.items
    }

    func deleteAgentMemory(id: String) async throws {
        try await sendVoid(
            path: "agent/memories/\(id)",
            method: "DELETE",
            body: nil
        )
    }

    func reportAgentAction(
        id: String,
        runID: String?,
        type: String,
        status: String,
        message: String?
    ) async throws {
        var payload: [String: Any] = [
            "action_type": type,
            "status": status,
        ]
        if let runID { payload["run_id"] = runID }
        if let message, !message.isEmpty { payload["message"] = message }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(
            path: "agent/actions/\(encoded)/result",
            method: "POST",
            body: body
        )
    }

    // MARK: - Cross-device data

    func syncFoodLog(_ log: FoodLog) async throws {
        let payload: [String: Any] = [
            "client_id": log.id.uuidString,
            "logged_at": Self.iso8601WithFractionalSeconds.string(from: log.date),
            "meal": log.meal.rawValue,
            "food_name": log.foodName,
            "grams": log.grams,
            "kcal": log.kcal,
            "protein": log.protein,
            "carbs": log.carbs,
            "fat": log.fat,
            "fiber": log.fiber ?? 0
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "diet/logs", method: "POST", body: body)
    }

    func deleteFoodLog(id: UUID) async throws {
        try await sendVoid(
            path: "diet/logs/\(id.uuidString)",
            method: "DELETE",
            body: nil
        )
    }

    func fetchFoodLogs() async throws -> [RemoteFoodLog] {
        let response: RemoteFoodLogResponse = try await send(
            path: "diet/logs",
            method: "GET",
            body: nil
        )
        return response.items
    }

    func syncBodyMetric(_ metric: BodyMetric) async throws {
        var payload: [String: Any] = [
            "client_id": metric.id.uuidString,
            "measured_at": Self.iso8601WithFractionalSeconds.string(from: metric.date),
            "weight_kg": metric.weightKG,
            "body_fat_pct": metric.bodyFatPCT,
            "waist_cm": metric.waistCM
        ]
        if let arm = metric.armCM { payload["arm_cm"] = arm }
        if let thigh = metric.thighCM { payload["thigh_cm"] = thigh }
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "body/metrics", method: "POST", body: body)
    }

    func deleteBodyMetric(id: UUID) async throws {
        try await sendVoid(
            path: "body/metrics/\(id.uuidString)",
            method: "DELETE",
            body: nil
        )
    }

    func fetchBodyMetrics() async throws -> [RemoteBodyMetric] {
        let response: RemoteBodyMetricResponse = try await send(
            path: "body/metrics",
            method: "GET",
            body: nil
        )
        return response.items
    }

    func syncEquipmentItem(_ item: EquipmentItem) async throws {
        var payload: [String: Any] = [
            "client_id": item.id.uuidString,
            "name": item.name,
            "notes": item.notes
        ]
        if let slug = item.slug { payload["slug"] = slug }
        if let muscle = item.muscle { payload["muscle"] = muscle.rawValue }
        if let equipment = item.equipment { payload["equipment"] = equipment.rawValue }
        if let source = item.source { payload["source"] = source }
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "equipment/items", method: "POST", body: body)
    }

    func deleteEquipmentItem(id: UUID) async throws {
        try await sendVoid(
            path: "equipment/items/\(id.uuidString)",
            method: "DELETE",
            body: nil
        )
    }

    func fetchEquipmentItems() async throws -> [RemoteEquipmentItem] {
        let response: RemoteEquipmentItemResponse = try await send(
            path: "equipment/items",
            method: "GET",
            body: nil
        )
        return response.items
    }

    // MARK: - 器械识别

    func scanEquipment(imageData: Data) async throws -> EquipmentScanResult {
        let data = try await upload(
            path: "equipment/scan",
            imageData: imageData,
            filename: "photo.jpg"
        )
        let response = try decode(EquipmentScanResponse.self, from: data)
        let candidates = response.candidates.compactMap { candidate -> EquipmentCandidate? in
            guard let exercise = ExerciseLibrary.exercise(slug: candidate.slug) else {
                return nil
            }
            return EquipmentCandidate(exercise: exercise, confidence: candidate.confidence)
        }
        return EquipmentScanResult(
            candidates: candidates,
            description: response.description ?? "",
            name: response.name ?? "",
            notInLibrary: response.notInLibrary ?? false
        )
    }

    func officialVideoURL(slug: String) async throws -> URL? {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let data = try await perform(path: "videos/\(encoded)", method: "GET", body: nil)
        let response = try decode(ExerciseVideoResponse.self, from: data)
        guard let text = response.video?.videoURL, let url = URL(string: text) else {
            return nil
        }
        return url
    }

    // MARK: - 体型照片分析

    func analyzeBody(imageData: Data) async throws -> BodyAnalysis {
        let data = try await upload(
            path: "body/analyze",
            imageData: imageData,
            filename: "body.jpg"
        )
        let response = try decode(BodyAnalysisResponse.self, from: data)
        return BodyAnalysis(
            summary: response.summary,
            focusAreas: response.focusAreas.compactMap { MuscleGroup(rawValue: $0) },
            recommendations: response.recommendations,
            confidence: response.confidence,
            disclaimer: response.disclaimer
        )
    }

    // MARK: - 饮食 / 外卖

    func analyzeFood(imageData: Data) async throws -> FoodRecognitionResult {
        let data = try await upload(
            path: "diet/analyze",
            imageData: imageData,
            filename: "meal.jpg"
        )
        let response = try decode(FoodAnalysisResponse.self, from: data)
        return FoodRecognitionResult(
            items: response.items.map { item in
                FoodRecognitionItem(
                    name: item.name,
                    grams: item.grams,
                    kcalPer100g: item.kcalPer100g,
                    proteinPer100g: item.proteinPer100g,
                    carbsPer100g: item.carbsPer100g,
                    fatPer100g: item.fatPer100g,
                    fiberPer100g: item.fiberPer100g,
                    confidence: item.confidence
                )
            },
            confidence: response.confidence,
            disclaimer: response.disclaimer,
            model: response.model ?? "remote",
            summary: response.summary ?? "",
            isFood: response.isFood ?? !response.items.isEmpty
        )
    }

    func reviewCoachVision(imageData: Data, question: String) async throws -> CoachVisionResult {
        let data = try await upload(
            path: "coach/vision",
            imageData: imageData,
            filename: "form.jpg",
            fields: ["question": question]
        )
        return try decode(CoachVisionResult.self, from: data)
    }

    func fetchDietPlan(dateString: String) async throws -> RemoteDietPlan {
        let body = try JSONSerialization.data(withJSONObject: ["date": dateString])
        return try await send(path: "diet/plan", method: "POST", body: body)
    }

    func fetchDietWeek(strategy: String, weekStart: String?) async throws -> RemoteDietWeek {
        var payload: [String: Any] = ["strategy": strategy]
        if let weekStart { payload["week_start"] = weekStart }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(path: "diet/plan/week", method: "POST", body: body)
    }

    func fetchSavedDietWeek(weekStart: String?) async throws -> RemoteDietWeek {
        var path = "diet/plan/week"
        if let weekStart,
           let encoded = weekStart.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?week_start=\(encoded)"
        }
        return try await send(path: path, method: "GET", body: nil)
    }

    func meituanLink(keyword: String) async throws -> URL? {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let data = try await perform(
            path: "diet/meituan-link?keyword=\(encoded)",
            method: "GET",
            body: nil
        )
        let response = try decode(MeituanLinkResponse.self, from: data)
        if let text = response.deeplink, let url = URL(string: text) {
            return url
        }
        if let text = response.h5URL, let url = URL(string: text) {
            return url
        }
        return nil
    }

    // MARK: - 网络

    private func send<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        timeout: TimeInterval = 90
    ) async throws -> T {
        let data = try await perform(
            path: path,
            method: method,
            body: body,
            timeout: timeout
        )
        return try decode(T.self, from: data)
    }

    private func sendVoid(path: String, method: String, body: Data?) async throws {
        _ = try await perform(path: path, method: method, body: body)
    }

    private func upload(
        path: String,
        imageData: Data,
        filename: String,
        fields: [String: String] = [:]
    ) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        for (name, value) in fields {
            body.append(contentsOf: Data("--\(boundary)\r\n".utf8))
            body.append(contentsOf: Data(
                "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8
            ))
            body.append(contentsOf: Data(value.utf8))
            body.append(contentsOf: Data("\r\n".utf8))
        }
        body.append(contentsOf: Data("--\(boundary)\r\n".utf8))
        body.append(contentsOf: Data(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8
        ))
        body.append(contentsOf: Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))

        return try await perform(
            path: path,
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
    }

    private func perform(
        path: String,
        method: String,
        body: Data?,
        contentType: String = "application/json",
        retried: Bool = false,
        timeout: TimeInterval = 90
    ) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString + "/" + path) else {
            throw APIError(message: "接口地址不合法")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token = AuthTokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(userID, forHTTPHeaderField: "X-User-Id")
        }
        request.httpBody = body
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            if [.cannotConnectToHost, .notConnectedToInternet, .timedOut, .networkConnectionLost]
                .contains(error.code) {
                throw APIError(
                    message: "无法连接服务端：请确认后端已启动，并在 Debug 构建中填写正确的局域网 API 地址。"
                )
            }
            throw APIError(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "网络响应异常")
        }
        if http.statusCode == 401,
           !retried,
           AuthTokenStore.shared.refreshToken != nil {
            if await refreshAccessToken() {
                return try await perform(
                    path: path,
                    method: method,
                    body: body,
                    contentType: contentType,
                    retried: true,
                    timeout: timeout
                )
            }
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "服务返回 \(http.statusCode)：\(text.prefix(200))", statusCode: http.statusCode)
        }
        return data
    }

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = AuthTokenStore.shared.refreshToken,
              let url = URL(string: AppConfig.apiBaseURL.absoluteString + "/auth/refresh") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "refresh_token": refreshToken
        ])
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }
            let refresh = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            AuthTokenStore.shared.updateTokens(
                accessToken: refresh.accessToken,
                refreshToken: refresh.refreshToken
            )
            return true
        } catch {
            return false
        }
    }

    private func birthDateString(age: Int) -> String {
        let date = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
        return Self.birthDateFormatter.string(from: date)
    }

    private func apiGoalType(_ type: GoalType) -> String {
        switch type {
        case .loseFat: return "lose_fat"
        case .buildMuscle: return "build_muscle"
        case .recomp: return "recomp"
        case .endurance: return "endurance"
        }
    }
}
