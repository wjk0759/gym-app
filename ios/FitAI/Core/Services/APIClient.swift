import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
}

struct APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let decoder: JSONDecoder
    private let userID = "00000000-0000-0000-0000-000000000001"

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: text) { return date }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: text) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期：\(text)"
            )
        }
        self.decoder = decoder
    }

    // MARK: - 档案

    func syncProfile(_ profile: UserProfile) async throws {
        var payload: [String: Any] = [
            "nickname": profile.nickname,
            "sex": profile.sex.rawValue,
            "birth_date": birthDateString(age: profile.age),
            "height_cm": profile.heightCM,
            "weight_kg": profile.weightKG,
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
        let body = try JSONSerialization.data(withJSONObject: payload)
        try await sendVoid(path: "me/goal", method: "PUT", body: body)
    }

    // MARK: - 健康检查

    func health() async throws -> Bool {
        let root = baseURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        var request = URLRequest(url: root.appendingPathComponent("health"))
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return false
        }
        return String(data: data, encoding: .utf8)?.contains("\"status\":\"ok\"") == true
    }

    // MARK: - 计划

    func generatePlan(force: Bool = true) async throws -> TrainingPlan {
        let body = try JSONSerialization.data(withJSONObject: ["force": force])
        return try await send(path: "plans/generate", method: "POST", body: body)
    }

    // MARK: - 对话

    func sendChat(message: String, sessionID: UUID? = nil) async throws -> ChatResponse {
        var payload: [String: Any] = ["message": message]
        if let sessionID { payload["session_id"] = sessionID.uuidString }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(path: "coach/chat", method: "POST", body: body)
    }

    // MARK: - 器械识别

    func scanEquipment(imageData: Data) async throws -> [EquipmentCandidate] {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append(contentsOf: Data("--\(boundary)\r\n".utf8))
        body.append(contentsOf: Data("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".utf8))
        body.append(contentsOf: Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(imageData)
        body.append(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))

        let data = try await perform(
            path: "equipment/scan",
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        let response = try decoder.decode(EquipmentScanResponse.self, from: data)
        return response.candidates.compactMap { candidate in
            guard let exercise = ExerciseLibrary.exercise(slug: candidate.slug) else {
                return nil
            }
            return EquipmentCandidate(exercise: exercise, confidence: candidate.confidence)
        }
    }

    // MARK: - 网络

    private func send<T: Decodable>(
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        let data = try await perform(path: path, method: method, body: body)
        return try decoder.decode(T.self, from: data)
    }

    private func sendVoid(path: String, method: String, body: Data?) async throws {
        _ = try await perform(path: path, method: method, body: body)
    }

    private func perform(
        path: String,
        method: String,
        body: Data?,
        contentType: String = "application/json"
    ) async throws -> Data {
        guard let url = URL(string: baseURL.absoluteString + "/" + path) else {
            throw APIError(message: "接口地址不合法")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(userID, forHTTPHeaderField: "X-User-Id")
        request.httpBody = body
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "服务返回 \(http.statusCode)：\(text.prefix(200))")
        }
        return data
    }

    private func birthDateString(age: Int) -> String {
        let date = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
