import Foundation

/// Owns the mechanics shared by every API endpoint: URL construction, auth
/// headers, decoding, upload encoding, timeout and one-shot token refresh.
///
/// `APIClient` stays focused on endpoints and payloads; future feature clients
/// can reuse this transport without copying retry/auth code.
struct APITransport {
    private let baseURL: URL
    private let anonymousUserID: String
    private let session: URLSession

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        anonymousUserID: String = "00000000-0000-0000-0000-000000000001",
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.anonymousUserID = anonymousUserID
        self.session = session
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = APIDateCoding.date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "无法解析日期：\(text)"
                )
            }
            return date
        }
        return try decoder.decode(type, from: data)
    }

    func send<T: Decodable>(
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

    func sendVoid(path: String, method: String, body: Data?) async throws {
        _ = try await perform(path: path, method: method, body: body)
    }

    func upload(
        path: String,
        imageData: Data,
        filename: String,
        fields: [String: String] = [:]
    ) async throws -> Data {
        var multipart = MultipartFormData()
        for (name, value) in fields {
            multipart.appendField(name: name, value: value)
        }
        multipart.appendFile(imageData, field: "file", filename: filename)

        return try await perform(
            path: path,
            method: "POST",
            body: multipart.finalized(),
            contentType: multipart.contentType
        )
    }

    func uploadMany(
        path: String,
        images: [Data],
        fields: [String: String] = [:]
    ) async throws -> Data {
        guard !images.isEmpty else {
            throw APIError(message: "没有可上传的图片")
        }

        var multipart = MultipartFormData()
        for (name, value) in fields {
            multipart.appendField(name: name, value: value)
        }
        for (index, imageData) in images.enumerated() {
            multipart.appendFile(
                imageData,
                field: "files",
                filename: "form-\(index + 1).jpg"
            )
        }

        return try await perform(
            path: path,
            method: "POST",
            body: multipart.finalized(),
            contentType: multipart.contentType
        )
    }

    func perform(
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
            request.setValue(anonymousUserID, forHTTPHeaderField: "X-User-Id")
        }
        request.httpBody = body
        request.timeoutInterval = timeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
              let url = URL(string: baseURL.absoluteString + "/auth/refresh") else {
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
            let (data, response) = try await session.data(for: request)
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
}
