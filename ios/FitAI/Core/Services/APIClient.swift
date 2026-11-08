import Foundation

struct APIError: LocalizedError {
    let message: String
    let statusCode: Int?
    /// Structured `error.code` from the API (`PRO_REQUIRED`, `RATE_LIMITED`, ...).
    let code: String?
    let retryAfter: Int?

    init(
        message: String,
        statusCode: Int? = nil,
        code: String? = nil,
        retryAfter: Int? = nil
    ) {
        self.message = message
        self.statusCode = statusCode
        self.code = code
        self.retryAfter = retryAfter
    }

    var errorDescription: String? { message }

    var isProRequired: Bool { code == "PRO_REQUIRED" }
    var isCoachQuotaExhausted: Bool { code == "COACH_QUOTA_EXHAUSTED" }

    var isRateLimited: Bool {
        code == "RATE_LIMITED" || code == "GENERATION_COOLDOWN"
            || code == "GENERATION_IN_PROGRESS"
    }
}

struct APIClient {
    static let shared = APIClient()

    var baseURL: URL { AppConfig.apiBaseURL }
    let transport = APITransport()

    init() {}

    // MARK: - 档案

    func fetchAccess() async throws -> AccessSnapshot {
        try await send(path: "me/access", method: "GET", body: nil)
    }

    func consumeOnboardingTrial() async throws -> AccessSnapshot {
        try await send(
            path: "me/onboarding-plan/consume",
            method: "POST",
            body: Data("{}".utf8)
        )
    }

    func syncProfile(_ profile: UserProfile) async throws {        var payload: [String: Any] = [
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
            "source": session.source ?? "phone",
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

    // MARK: - Transport

    func send<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        timeout: TimeInterval = 90,
        headers: [String: String] = [:]
    ) async throws -> T {
        try await transport.send(
            path: path,
            method: method,
            body: body,
            timeout: timeout,
            headers: headers
        )
    }

    func idempotencyHeaders(_ key: String?) -> [String: String] {
        guard let key, !key.isEmpty else { return [:] }
        return ["Idempotency-Key": key]
    }

    func sendVoid(path: String, method: String, body: Data?) async throws {
        try await transport.sendVoid(path: path, method: method, body: body)
    }

    func upload(
        path: String,
        imageData: Data,
        filename: String,
        fields: [String: String] = [:],
        headers: [String: String] = [:]
    ) async throws -> Data {
        try await transport.upload(
            path: path,
            imageData: imageData,
            filename: filename,
            fields: fields,
            headers: headers
        )
    }

    func uploadMany(
        path: String,
        images: [Data],
        fields: [String: String] = [:],
        headers: [String: String] = [:]
    ) async throws -> Data {
        try await transport.uploadMany(
            path: path,
            images: images,
            fields: fields,
            headers: headers
        )
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try transport.decode(type, from: data)
    }

    func perform(
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
