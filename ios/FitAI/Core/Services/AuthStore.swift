import AuthenticationServices
import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AuthStore {
    var isAuthenticated = false
    var isRestoring = true
    var isWorking = false
    var errorMessage: String?
    var userID: String?
    var phone: String?
    var onboardingRequired = false

    private var didRestore = false
    private var webAuthSession: ASWebAuthenticationSession?
    private var presenter = SocialAuthPresenter()

    init() {
        userID = AuthTokenStore.shared.userID
        isAuthenticated = AuthTokenStore.shared.accessToken != nil
    }

    func restoreIfNeeded() async {
        guard !didRestore else { return }
        didRestore = true
        defer { isRestoring = false }

        guard AuthTokenStore.shared.accessToken != nil else {
            isAuthenticated = false
            return
        }

        do {
            _ = try await getMe()
            isAuthenticated = true
        } catch {
            if await refreshTokens() {
                do {
                    _ = try await getMe()
                    isAuthenticated = true
                    return
                } catch {
                    // fall through to clear
                }
            }
            clearSession()
        }
    }

    // MARK: - 手机验证码

    @discardableResult
    func sendCode(phone: String, purpose: String = "login") async throws -> String? {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let response: SmsSendResponse = try await request(
            "/auth/phone/send-code",
            body: ["phone": phone, "purpose": purpose]
        )
        return response.devCode
    }

    func resetPassword(phone: String, code: String, newPassword: String) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let _: EmptyResponse = try await request(
            "/auth/password/reset",
            body: [
                "phone": phone,
                "code": code,
                "password": newPassword
            ]
        )
    }

    func setPassword(_ newPassword: String) async throws {
        guard let token = AuthTokenStore.shared.accessToken else {
            throw AuthError(message: "请先登录")
        }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let _: EmptyResponse = try await request(
            "/auth/password/set",
            body: ["password": newPassword],
            token: token
        )
    }

    func loginWithPhone(phone: String, code: String) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let response: AuthResponse = try await request(
            "/auth/phone/login",
            body: [
                "phone": phone,
                "code": code,
                "device_name": deviceName,
                "agreed_terms": true
            ]
        )
        apply(response)
        self.phone = phone
    }

    // MARK: - 账号密码

    func loginWithPassword(account: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let response: AuthResponse = try await request(
            "/auth/password/login",
            body: [
                "account": account,
                "password": password,
                "device_name": deviceName,
                "agreed_terms": true
            ]
        )
        apply(response)
        if account.count == 11, account.hasPrefix("1") {
            phone = account
        }
    }

    func registerWithPassword(
        account: String,
        password: String,
        phone: String,
        code: String
    ) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let response: AuthResponse = try await request(
            "/auth/password/register",
            body: [
                "account": account,
                "password": password,
                "phone": phone,
                "code": code,
                "device_name": deviceName,
                "agreed_terms": true
            ]
        )
        apply(response)
        self.phone = phone
    }

    // MARK: - 微信 / QQ

    func loginWithSocial(provider: String) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil

        let start: OAuthStartResponse = try await request(
            "/auth/oauth/\(provider)/start",
            method: "GET"
        )
        guard let url = URL(string: start.authorizeURL) else {
            throw AuthError(message: "授权地址无效")
        }
        let scheme = URLComponents(string: start.callbackScheme)?.scheme ?? "fitai"
        let callback = try await presentWebAuth(url: url, scheme: scheme)
        guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let ticket = components.queryItems?.first(where: { $0.name == "ticket" })?.value else {
            throw AuthError(message: "未获得授权凭证")
        }

        let response: AuthResponse = try await request(
            "/auth/oauth/exchange",
            body: [
                "ticket": ticket,
                "device_name": deviceName,
                "agreed_terms": true
            ]
        )
        apply(response)
    }

    // MARK: - Sign in with Apple

    func loginWithApple(identityToken: String, fullName: String?) async throws {
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        var body: [String: Any] = [
            "identity_token": identityToken,
            "device_name": deviceName,
            "agreed_terms": true
        ]
        if let fullName, !fullName.isEmpty {
            body["full_name"] = fullName
        }
        let response: AuthResponse = try await request(
            "/auth/apple/login",
            body: body
        )
        apply(response)
    }

    // MARK: - 静默续期与退出

    @discardableResult
    func refreshTokens() async -> Bool {
        guard let refresh = AuthTokenStore.shared.refreshToken else { return false }
        do {
            let response: RefreshResponse = try await request(
                "/auth/refresh",
                body: ["refresh_token": refresh, "device_name": deviceName]
            )
            AuthTokenStore.shared.updateTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )
            isAuthenticated = true
            return true
        } catch {
            return false
        }
    }

    func logout() async {
        if let token = AuthTokenStore.shared.accessToken {
            let _: EmptyResponse? = try? await request(
                "/auth/logout",
                method: "POST",
                token: token
            )
        }
        clearSession()
    }

    func deleteAccount() async throws {
        guard let token = AuthTokenStore.shared.accessToken else {
            throw AuthError(message: "请先登录")
        }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        let _: EmptyResponse = try await request(
            "/me",
            method: "DELETE",
            token: token
        )
        clearSession()
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - 内部

    private var deviceName: String {
        UIDevice.current.name
    }

    private func apply(_ response: AuthResponse) {
        AuthTokenStore.shared.save(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            userID: response.userID
        )
        userID = response.userID
        onboardingRequired = response.onboardingRequired
        isAuthenticated = true
    }

    private func clearSession() {
        AuthTokenStore.shared.clear()
        userID = nil
        phone = nil
        onboardingRequired = false
        isAuthenticated = false
    }

    private func getMe() async throws -> MeResponse {
        guard let token = AuthTokenStore.shared.accessToken else {
            throw AuthError(message: "未登录")
        }
        let response: MeResponse = try await request("/auth/me", method: "GET", token: token)
        if let phone = response.phone {
            self.phone = phone
        }
        return response
    }

    private func presentWebAuth(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: scheme
            ) { callback, error in
                self.webAuthSession = nil
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error {
                    if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        continuation.resume(throwing: AuthError(message: "已取消授权"))
                    } else {
                        continuation.resume(throwing: AuthError(message: error.localizedDescription))
                    }
                } else {
                    continuation.resume(throwing: AuthError(message: "授权失败，请重试"))
                }
            }
            session.presentationContextProvider = presenter
            session.prefersEphemeralWebBrowserSession = false
            webAuthSession = session
            if !session.start() {
                webAuthSession = nil
                continuation.resume(throwing: AuthError(message: "无法打开授权页面"))
            }
        }
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "POST",
        body: [String: Any]? = nil,
        token: String? = nil
    ) async throws -> T {
        guard let url = URL(string: AppConfig.apiBaseURL.absoluteString + path) else {
            throw AuthError(message: "接口地址无效")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            if [.cannotConnectToHost, .notConnectedToInternet, .timedOut, .networkConnectionLost]
                .contains(error.code) {
                throw AuthError(
                    message: "无法连接服务端。请确认后端已启动；真机调试时请在登录页「开发服务器」填写电脑的局域网地址。"
                )
            }
            throw AuthError(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError(message: "网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            throw AuthError(message: message)
        }
        if T.self == EmptyResponse.self {
            guard let empty = EmptyResponse() as? T else {
                throw AuthError(message: "登录响应格式异常，请稍后重试")
            }
            return empty
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func errorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "登录失败，请稍后再试"
        }
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let detail = object["detail"] as? String {
            return detail
        }
        if let detail = object["detail"] as? [String: Any],
           let message = detail["message"] as? String {
            return message
        }
        return "登录失败，请稍后再试"
    }
}

struct AuthError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct SmsSendResponse: Decodable {
    let devCode: String?

    enum CodingKeys: String, CodingKey {
        case devCode = "dev_code"
    }
}

private struct AuthResponse: Decodable {
    let userID: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let isNewUser: Bool
    let onboardingRequired: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case isNewUser = "is_new_user"
        case onboardingRequired = "onboarding_required"
    }
}

private struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct OAuthStartResponse: Decodable {
    let authorizeURL: String
    let callbackScheme: String
    let mode: String

    enum CodingKeys: String, CodingKey {
        case authorizeURL = "authorize_url"
        case callbackScheme = "callback_scheme"
        case mode
    }
}

private struct MeResponse: Decodable {
    let userID: String
    let phone: String?
    let onboardingRequired: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case phone
        case onboardingRequired = "onboarding_required"
    }
}

private struct EmptyResponse: Decodable {}

private final class SocialAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
