import Foundation

private struct WorkoutActionExecuteRequest: Encodable {
    let planID: String
    let dayID: String
    let expectedPlanVersion: Int
    let changes: [AgentWorkoutChange]

    enum CodingKeys: String, CodingKey {
        case planID = "plan_id"
        case dayID = "day_id"
        case expectedPlanVersion = "expected_plan_version"
        case changes
    }
}

extension APIClient {
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
        onboarding: Bool = false,
        preview: Bool = false,
        strictEquipment: Bool = false,
        split: SplitType,
        focus: [String] = [],
        idempotencyKey: String? = nil
    ) async throws -> TrainingPlan {
        let body = try JSONSerialization.data(withJSONObject: [
            "force": force,
            "onboarding": onboarding,
            "preview": preview,
            "strict_equipment": strictEquipment,
            "split": split.rawValue,
            "focus": focus
        ])
        // AI 计划生成在 DeepSeek reasoning 开启时可能接近 100 秒；
        // 90 秒会先于服务端返回而失败，随后又落回本地模板。
        return try await send(
            path: "plans/generate",
            method: "POST",
            body: body,
            timeout: 150,
            headers: idempotencyHeaders(idempotencyKey)
        )
    }

    func fetchCurrentPlan() async throws -> TrainingPlan? {
        do {
            let plan: TrainingPlan = try await send(
                path: "plans/current",
                method: "GET",
                body: nil
            )
            return plan
        } catch let error as APIError where error.statusCode == 404 {
            return nil
        }
    }

    func updatePlanDay(
        planID: UUID,
        dayID: UUID,
        expectedPlanVersion: Int,
        exercises: [PlanExercise]
    ) async throws -> TrainingPlan {
        struct Payload: Encodable {
            let expectedPlanVersion: Int
            let exercises: [PlanExercise]

            enum CodingKeys: String, CodingKey {
                case expectedPlanVersion = "expected_plan_version"
                case exercises
            }
        }
        let body = try JSONEncoder().encode(
            Payload(
                expectedPlanVersion: expectedPlanVersion,
                exercises: exercises
            )
        )
        return try await send(
            path: "plans/\(planID.uuidString.lowercased())/days/\(dayID.uuidString.lowercased())",
            method: "PATCH",
            body: body
        )
    }

    func importPlan(
        _ plan: TrainingPlan,
        expectedPlanVersion: Int? = nil
    ) async throws -> TrainingPlan {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(APIDateCoding.iso8601WithFractionalSeconds.string(from: date))
        }
        let encoded = try encoder.encode(plan)
        let body: Data
        if let expectedPlanVersion {
            var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] ?? [:]
            object["expected_plan_version"] = expectedPlanVersion
            body = try JSONSerialization.data(withJSONObject: object)
        } else {
            body = encoded
        }
        return try await send(
            path: "plans/\(plan.id.uuidString.lowercased())",
            method: "PUT",
            body: body
        )
    }

    func activatePlan(id: UUID) async throws -> TrainingPlan {
        try await send(
            path: "plans/\(id.uuidString.lowercased())/activate",
            method: "POST",
            body: nil,
            timeout: 30
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

    func agentFeedback(
        messageID: String,
        runID: String?,
        rating: String,
        reason: String?
    ) async throws {
        var payload: [String: Any] = [
            "message_id": messageID,
            "rating": rating,
        ]
        if let runID { payload["run_id"] = runID }
        if let reason { payload["reason"] = reason }
        try await sendVoid(
            path: "agent/feedback",
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: payload)
        )
    }

    func executeWorkoutAction(
        actionID: String,
        planID: String,
        dayID: String,
        expectedPlanVersion: Int,
        changes: [AgentWorkoutChange]
    ) async throws -> TrainingPlan {
        let request = WorkoutActionExecuteRequest(
            planID: planID,
            dayID: dayID,
            expectedPlanVersion: expectedPlanVersion,
            changes: changes
        )
        let body = try JSONEncoder().encode(request)
        let response: WorkoutActionExecuteResponse = try await send(
            path: "agent/actions/\(actionID)/execute",
            method: "POST",
            body: body,
            timeout: 30
        )
        return response.program
    }

    func undoWorkoutAction(actionID: String) async throws -> TrainingPlan {
        let response: WorkoutActionExecuteResponse = try await send(
            path: "agent/actions/\(actionID)/undo",
            method: "POST",
            body: nil,
            timeout: 30
        )
        return response.program
    }

    // MARK: - Cross-device data

    func syncFoodLog(_ log: FoodLog) async throws {
        var payload: [String: Any] = [
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
        if let planDate = log.planDate {
            payload["plan_date"] = APIDateCoding.dateOnlyLocal.string(from: planDate)
        }
        if let planMeal = log.planMeal {
            payload["plan_meal"] = planMeal.rawValue
        }
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
            "measured_at": APIDateCoding.iso8601WithFractionalSeconds.string(from: metric.date)
        ]
        if let weight = metric.weightKG { payload["weight_kg"] = weight }
        if let bodyFat = metric.bodyFatPCT { payload["body_fat_pct"] = bodyFat }
        if let waist = metric.waistCM { payload["waist_cm"] = waist }
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
            "notes": item.notes,
            "enabled_exercise_slugs": item.enabledExerciseSlugs ?? [],
            "target_muscles": item.targetMuscleList
        ]
        if let equipmentType = item.equipmentType { payload["equipment_type"] = equipmentType }
        if let category = item.category { payload["category"] = category }
        if let slug = item.slug { payload["slug"] = slug }
        if let muscle = item.muscle { payload["muscle"] = muscle.rawValue }
        if let equipment = item.equipment { payload["equipment"] = equipment.rawValue }
        if let source = item.source { payload["source"] = source }
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "equipment/items", method: "POST", body: body)
    }

    // MARK: - 通用器械

    func fetchUniversalEquipment() async throws -> [RemoteUniversalEquipmentItem] {
        let response: RemoteUniversalEquipmentResponse = try await send(
            path: "equipment/universal",
            method: "GET",
            body: nil
        )
        return response.items
    }

    func replaceUniversalEquipment(slugs: [String]) async throws {
        let body = try JSONSerialization.data(
            withJSONObject: ["enabled_slugs": slugs]
        )
        try await sendVoid(path: "equipment/universal", method: "PUT", body: body)
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

    func scanEquipment(
        imageData: Data,
        ocrText: String = "",
        idempotencyKey: String? = nil
    ) async throws -> EquipmentScanResult {
        var fields: [String: String] = [:]
        let trimmedText = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            fields["ocr_text"] = String(trimmedText.prefix(300))
        }
        let data = try await upload(
            path: "equipment/scan",
            imageData: imageData,
            filename: "photo.jpg",
            fields: fields,
            headers: idempotencyHeaders(idempotencyKey)
        )
        let response = try decode(EquipmentScanResponse.self, from: data)

        func resolve(
            _ candidates: [EquipmentScanResponse.Candidate]
        ) -> [EquipmentCandidate] {
            candidates.compactMap { candidate -> EquipmentCandidate? in
                guard let exercise = ExerciseLibrary.exercise(slug: candidate.slug) else {
                    return nil
                }
                return EquipmentCandidate(
                    exercise: exercise,
                    confidence: candidate.confidence
                )
            }
        }

        let options = (response.equipmentCandidates ?? []).compactMap {
            option -> EquipmentMatchOption? in
            let actions = resolve(option.candidates)
            guard !actions.isEmpty else { return nil }
            return EquipmentMatchOption(
                slug: option.slug,
                name: option.nameZh,
                confidence: option.confidence,
                candidates: actions
            )
        }
        let candidates = resolve(response.candidates)
        return EquipmentScanResult(
            candidates: candidates,
            description: response.description ?? "",
            name: response.name ?? "",
            notInLibrary: response.notInLibrary
                ?? (!response.candidates.isEmpty && candidates.isEmpty),
            warning: response.warning,
            status: response.status ?? "ok",
            equipmentName: response.equipmentName,
            confidence: response.confidence,
            equipmentOptions: options
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

    func analyzeBody(
        imageData: Data,
        idempotencyKey: String? = nil
    ) async throws -> BodyAnalysis {
        let data = try await upload(
            path: "body/analyze",
            imageData: imageData,
            filename: "body.jpg",
            headers: idempotencyHeaders(idempotencyKey)
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

    func analyzeFood(
        imageData: Data,
        idempotencyKey: String? = nil
    ) async throws -> FoodRecognitionResult {
        let data = try await upload(
            path: "diet/analyze",
            imageData: imageData,
            filename: "meal.jpg",
            headers: idempotencyHeaders(idempotencyKey)
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
                    confidence: item.confidence,
                    gramsMin: item.gramsMin,
                    gramsMax: item.gramsMax,
                    portionConfidence: item.portionConfidence,
                    portionBasis: item.portionBasis
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
        sessionID: UUID? = nil,
        idempotencyKey: String? = nil
    ) async throws -> CoachVisionResult {
        var fields = ["question": question]
        if let sessionID {
            fields["session_id"] = sessionID.uuidString.lowercased()
        }
        let data = try await upload(
            path: "coach/vision",
            imageData: imageData,
            filename: "form.jpg",
            fields: fields,
            headers: idempotencyHeaders(idempotencyKey)
        )
        return try decode(CoachVisionResult.self, from: data)
    }

    func reviewCoachVisionBatch(
        imageData: [Data],
        question: String,
        sessionID: UUID? = nil,
        idempotencyKey: String? = nil
    ) async throws -> CoachVisionResult {
        var fields = ["question": question]
        if let sessionID {
            fields["session_id"] = sessionID.uuidString.lowercased()
        }
        let data = try await uploadMany(
            path: "coach/vision/batch",
            images: imageData,
            fields: fields,
            headers: idempotencyHeaders(idempotencyKey)
        )
        return try decode(CoachVisionResult.self, from: data)
    }

    func fetchDietPlan(
        dateString: String,
        idempotencyKey: String? = nil
    ) async throws -> RemoteDietPlan {
        let body = try JSONSerialization.data(withJSONObject: ["date": dateString])
        return try await send(
            path: "diet/plan",
            method: "POST",
            body: body,
            headers: idempotencyHeaders(idempotencyKey)
        )
    }

    func fetchDietReview(from: String, to: String) async throws -> RemoteDietReview {
        let start = from.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? from
        let end = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to
        return try await send(
            path: "diet/review?from=\(start)&to=\(end)",
            method: "GET",
            body: nil
        )
    }

    func fetchDietTargets(dateString: String) async throws -> RemoteDietTargets {
        let encoded = dateString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? dateString
        return try await send(
            path: "diet/targets?date=\(encoded)",
            method: "GET",
            body: nil
        )
    }

    func swapDietMeal(dateString: String, meal: MealType) async throws -> RemoteDietPlan {
        let encoded = dateString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? dateString
        return try await send(
            path: "diet/plan/\(encoded)/meals/\(meal.rawValue)/swap",
            method: "POST",
            body: nil
        )
    }

    func fetchSavedDietPlan(dateString: String) async throws -> RemoteDietPlan? {
        let encoded = dateString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? dateString
        do {
            let plan: RemoteDietPlan = try await send(
                path: "diet/plan?date=\(encoded)",
                method: "GET",
                body: nil
            )
            return plan
        } catch let error as APIError where error.statusCode == 404 {
            return nil
        }
    }

    func syncStoreKitTransaction(signedTransaction: String) async throws -> AccessSnapshot {
        let body = try JSONSerialization.data(withJSONObject: [
            "signed_transaction": signedTransaction
        ])
        return try await send(
            path: "me/storekit/transactions",
            method: "POST",
            body: body,
            timeout: 30
        )
    }

    func fetchDietWeek(
        strategy: String,
        weekStart: String?,
        idempotencyKey: String? = nil
    ) async throws -> RemoteDietWeek {
        var payload: [String: Any] = ["strategy": strategy]
        if let weekStart { payload["week_start"] = weekStart }
        let body = try JSONSerialization.data(withJSONObject: payload)
        // A seven-day menu with recipes is a larger model response than the
        // one-day plan; keep the client timeout aligned with plan generation.
        return try await send(
            path: "diet/plan/week",
            method: "POST",
            body: body,
            timeout: 180,
            headers: idempotencyHeaders(idempotencyKey)
        )
    }

    func fetchSavedDietWeek(weekStart: String?) async throws -> RemoteDietWeek {
        var path = "diet/plan/week"
        if let weekStart,
           let encoded = weekStart.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "?week_start=\(encoded)"
        }
        return try await send(path: path, method: "GET", body: nil)
    }
}
