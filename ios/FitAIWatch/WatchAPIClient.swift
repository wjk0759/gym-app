import Foundation
import FitAIWorkoutCore

struct WatchAPIError: LocalizedError {
    let message: String
    let statusCode: Int?
    let code: String?
    let sessionExpired: Bool

    init(
        message: String,
        statusCode: Int? = nil,
        code: String? = nil,
        sessionExpired: Bool = false
    ) {
        self.message = message
        self.statusCode = statusCode
        self.code = code
        self.sessionExpired = sessionExpired
    }

    var errorDescription: String? { message }
}

struct WatchVoiceReply: Decodable {
    let reply: String
    let speechText: String
    let safetyFlag: String?
    let requiresPhoneConfirmation: Bool
    let serverTime: Date?

    enum CodingKeys: String, CodingKey {
        case reply
        case speechText = "speech_text"
        case safetyFlag = "safety_flag"
        case requiresPhoneConfirmation = "requires_phone_confirmation"
        case serverTime = "server_time"
    }
}

private struct WatchAccessResponse: Decodable {
    let isPro: Bool
    let proExpiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case isPro = "is_pro"
        case proExpiresAt = "pro_expires_at"
    }
}

private struct WatchRefreshResponse: Decodable {
    let userID: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

/// Minimal standalone HTTP client for the watch. It only covers read-only
/// coach voice and entitlement refresh; workout mutations stay local until the
/// phone syncs them.
@MainActor
final class WatchAPIClient {
    static let shared = WatchAPIClient()

    private let session = URLSession.shared
    private let credentials = WatchCredentialStore.shared

    private init() {}

    var isConfigured: Bool {
        credentials.apiBaseURL != nil && credentials.auth != nil
    }

    func voice(message: String, context: String?) async throws -> WatchVoiceReply {
        var payload: [String: Any] = ["message": message]
        if let context, !context.isEmpty {
            payload["context"] = String(context.prefix(2000))
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await perform(
            path: "coach/voice",
            method: "POST",
            body: body
        )
        return try decode(WatchVoiceReply.self, from: data)
    }

    func refreshAccess() async throws -> WatchAccess {
        let data = try await perform(path: "me/access", method: "GET", body: nil)
        let response = try decode(WatchAccessResponse.self, from: data)
        return WatchAccess(
            isPro: response.isPro,
            proExpiresAt: response.proExpiresAt,
            lastVerifiedAt: Date()
        )
    }

    func refreshTokensIfNeeded() async throws {
        guard let auth = credentials.auth else { throw notSignedIn }
        if auth.expiresAt.timeIntervalSinceNow > 60 { return }
        _ = try await refreshTokens()
    }

    @discardableResult
    func refreshTokens() async throws -> WatchAuth {
        guard let auth = credentials.auth,
              let baseURL = credentials.apiBaseURL else {
            throw notSignedIn
        }
        var request = URLRequest(url: endpoint(baseURL, "auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(auth.deviceID, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "refresh_token": auth.refreshToken,
            "device_name": "Apple Watch"
        ])
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WatchAPIError(message: "手表没有网络，请稍后重试")
        }
        guard let http = response as? HTTPURLResponse else {
            throw WatchAPIError(message: "网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                credentials.clearAuth()
                throw WatchAPIError(
                    message: "手表登录已失效，请在 iPhone 重新打开训练",
                    statusCode: http.statusCode,
                    sessionExpired: true
                )
            }
            throw WatchAPIError(
                message: "刷新登录失败（\(http.statusCode)）",
                statusCode: http.statusCode
            )
        }
        let decoded = try decode(WatchRefreshResponse.self, from: data)
        let updated = WatchAuth(
            userID: decoded.userID,
            deviceID: auth.deviceID,
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(decoded.expiresIn)
        )
        credentials.update(auth: updated)
        return updated
    }

    private func perform(
        path: String,
        method: String,
        body: Data?,
        retried: Bool = false
    ) async throws -> Data {
        guard let auth = credentials.auth,
              let baseURL = credentials.apiBaseURL else {
            throw notSignedIn
        }
        if auth.expiresAt.timeIntervalSinceNow < 60 {
            _ = try await refreshTokens()
        }
        var request = URLRequest(url: endpoint(baseURL, path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(auth.deviceID, forHTTPHeaderField: "X-Device-ID")
        if let current = credentials.auth {
            request.setValue(
                "Bearer \(current.accessToken)",
                forHTTPHeaderField: "Authorization"
            )
        }
        request.httpBody = body
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WatchAPIError(message: "手表没有网络，请稍后重试")
        }
        guard let http = response as? HTTPURLResponse else {
            throw WatchAPIError(message: "网络响应异常")
        }
        if http.statusCode == 401, !retried {
            _ = try await refreshTokens()
            return try await perform(
                path: path,
                method: method,
                body: body,
                retried: true
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            throw parseError(data: data, statusCode: http.statusCode)
        }
        return data
    }

    private func parseError(data: Data, statusCode: Int) -> WatchAPIError {
        let parsed = (try? JSONSerialization.jsonObject(with: data))
            as? [String: Any]
        let error = parsed?["error"] as? [String: Any]
        let code = error?["code"] as? String
        let message = error?["message"] as? String
        if code == "PRO_REQUIRED" {
            return WatchAPIError(
                message: "手表训练和语音教练需要叫练 Pro",
                statusCode: statusCode,
                code: code
            )
        }
        if code == "COACH_QUOTA_EXHAUSTED" {
            return WatchAPIError(
                message: "今日免费教练额度已用完",
                statusCode: statusCode,
                code: code
            )
        }
        return WatchAPIError(
            message: message ?? "服务暂时不可用（\(statusCode)）",
            statusCode: statusCode,
            code: code
        )
    }

    private func endpoint(_ baseURL: URL, _ path: String) -> URL {
        var text = baseURL.absoluteString
        while text.hasSuffix("/") { text.removeLast() }
        return URL(string: text + "/" + path) ?? baseURL
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            if let date = fractional.date(from: text)
                ?? standard.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解析日期：\(text)"
            )
        }
        return try decoder.decode(type, from: data)
    }

    private var notSignedIn: WatchAPIError {
        WatchAPIError(
            message: "尚未收到 iPhone 的训练预载",
            sessionExpired: true
        )
    }
}
