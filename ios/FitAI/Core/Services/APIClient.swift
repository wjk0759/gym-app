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

struct APIClient {
    static let shared = APIClient()

    private var baseURL: URL { AppConfig.apiBaseURL }
    private let transport = APITransport()

    init() {}

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
        payload["target_date"] = APIDateCoding.dateOnlyLocal.string(from: profile.targetDate)
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "me/goal", method: "PUT", body: body)
    }

    // MARK: - 训练记录

    /// The create and update endpoints share the same shape; only `client_id`
    /// differs. Keeping this in one builder avoids the two payloads drifting.
    private func workoutPayload(_ session: WorkoutSession, includeClientID: Bool) -> [String: Any] {
        let finishedAt = session.date
        let startedAt = finishedAt.addingTimeInterval(-Double(max(0, session.durationMinutes) * 60))
        var payload: [String: Any] = [
            "started_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: startedAt),
            "finished_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: finishedAt),
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
        if includeClientID {
            payload["client_id"] = session.id.uuidString
        }
        if let notes = session.notes, !notes.isEmpty {
            payload["notes"] = notes
        }
        if let day = session.programDayID {
            payload["program_day_id"] = day
        }
        return payload
    }

    func createWorkout(_ session: WorkoutSession) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: workoutPayload(session, includeClientID: true))
        let response: WorkoutCreateResponse = try await send(
            path: "workouts",
            method: "POST",
            body: body
        )
        return response.id
    }

    func updateWorkout(id: String, session: WorkoutSession) async throws {
        let body = try JSONSerialization.data(withJSONObject: workoutPayload(session, includeClientID: false))
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
        let text = APIDateCoding.dateOnlyUTC.string(from: from)
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
            try container.encode(APIDateCoding.iso8601WithFractionalSeconds.string(from: date))
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
        if let sessionID { payload["session_id"] = sessionID.uuidString.lowercased() }
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
        if let sessionID { payload["session_id"] = sessionID.uuidString.lowercased() }
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
            "logged_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: log.date),
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
            "measured_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: metric.date),
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

    func reviewCoachVision(
        imageData: Data,
        question: String,
        sessionID: UUID? = nil
    ) async throws -> CoachVisionResult {
        var fields = ["question": question]
        if let sessionID {
            fields["session_id"] = sessionID.uuidString.lowercased()
        }
        let data = try await upload(
            path: "coach/vision",
            imageData: imageData,
            filename: "form.jpg",
            fields: fields
        )
        return try decode(CoachVisionResult.self, from: data)
    }

    func reviewCoachVisionBatch(
        imageData: [Data],
        question: String,
        sessionID: UUID? = nil
    ) async throws -> CoachVisionResult {
        var fields = ["question": question]
        if let sessionID {
            fields["session_id"] = sessionID.uuidString.lowercased()
        }
        let data = try await uploadMany(
            path: "coach/vision/batch",
            images: imageData,
            fields: fields
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
        // A seven-day menu with recipes is a larger model response than the
        // one-day plan; keep the client timeout aligned with plan generation.
        return try await send(path: "diet/plan/week", method: "POST", body: body, timeout: 180)
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

    // MARK: - Transport

    private func send<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        timeout: TimeInterval = 90
    ) async throws -> T {
        try await transport.send(path: path, method: method, body: body, timeout: timeout)
    }

    private func sendVoid(path: String, method: String, body: Data?) async throws {
        try await transport.sendVoid(path: path, method: method, body: body)
    }

    private func upload(
        path: String,
        imageData: Data,
        filename: String,
        fields: [String: String] = [:]
    ) async throws -> Data {
        try await transport.upload(
            path: path,
            imageData: imageData,
            filename: filename,
            fields: fields
        )
    }

    private func uploadMany(
        path: String,
        images: [Data],
        fields: [String: String] = [:]
    ) async throws -> Data {
        try await transport.uploadMany(path: path, images: images, fields: fields)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try transport.decode(type, from: data)
    }

    private func perform(
        path: String,
        method: String,
        body: Data?,
        contentType: String = "application/json",
        timeout: TimeInterval = 90
    ) async throws -> Data {
        try await transport.perform(
            path: path,
            method: method,
            body: body,
            contentType: contentType,
            timeout: timeout
        )
    }

    private func birthDateString(age: Int) -> String {
        APIDateCoding.birthDateString(age: age)
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
