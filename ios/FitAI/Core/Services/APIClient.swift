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

struct APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder = JSONEncoder()

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

    func generatePlan() async throws -> TrainingPlan {
        let body = try JSONSerialization.data(withJSONObject: ["force": false])
        return try await send(path: "plans/generate", method: "POST", body: body)
    }

    func sendChat(message: String, sessionID: UUID? = nil) async throws -> ChatResponse {
        var payload: [String: Any] = ["message": message]
        if let sessionID { payload["session_id"] = sessionID.uuidString }
        let body = try JSONSerialization.data(withJSONObject: payload)
        return try await send(path: "coach/chat", method: "POST", body: body)
    }

    private func send<T: Decodable>(
        path: String,
        method: String,
        body: Data?
    ) async throws -> T {
        guard let url = URL(string: baseURL.absoluteString + "/" + path) else {
            throw APIError(message: "接口地址不合法")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("00000000-0000-0000-0000-000000000001", forHTTPHeaderField: "X-User-Id")
        request.httpBody = body
        request.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "服务返回 \(http.statusCode)：\(text.prefix(200))")
        }
        return try decoder.decode(T.self, from: data)
    }
}
