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
    var avatarURL: URL?
    var trainingStage: Experience = .beginner
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
                    // fall through to the status check below
                }
            }
            if let authError = error as? AuthError,
               authError.statusCode == 401 || authError.statusCode == 403 {
                clearSession()
            } else {
                // Network/5xx should not destroy a valid local session.
                isAuthenticated = AuthTokenStore.shared.accessToken != nil
            }
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

    func setPassword(_ newPassword: String, currentPassword: String? = nil) async throws {
        guard let token = AuthTokenStore.shared.accessToken else {
            throw AuthError(message: "请先登录")
        }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        var body: [String: Any] = ["password": newPassword]
        if let currentPassword, !currentPassword.isEmpty {
            body["current_password"] = currentPassword
        }
        let _: EmptyResponse = try await request(
            "/auth/password/set",
            body: body,
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
        guard AuthTokenStore.shared.refreshToken != nil else { return false }
        if await TokenRefreshCoordinator.shared.refresh() {
            isAuthenticated = true
            return true
        }
        return false
    }

    /// Defensive fallback for a refresh token rejected by the server. The
    /// coordinator also posts this event; both paths converge here.
    func handleSessionExpired() {
        guard isAuthenticated || AuthTokenStore.shared.accessToken != nil else {
            return
        }
        clearSession()
        errorMessage = "登录已失效，请重新登录"
    }

    /// Called when the app becomes active. Extending the refresh session is
    /// deliberately cheap and idempotent; normal usage rolls it forward by 30
    /// days without forcing a new login.
    func touchSessionIfNeeded() async {
        guard AuthTokenStore.shared.accessToken != nil else { return }
        let key = "fitai_last_session_touch"
        let last = UserDefaults.standard.object(forKey: key) as? Date
        if let last, Date().timeIntervalSince(last) < 12 * 60 * 60 {
            return
        }
        if await touchSessionOnce() {
            UserDefaults.standard.set(Date(), forKey: key)
            return
        }
        if await refreshTokens(), await touchSessionOnce() {
            UserDefaults.standard.set(Date(), forKey: key)
        }
    }

    private func touchSessionOnce() async -> Bool {
        guard let token = AuthTokenStore.shared.accessToken else { return false }
        do {
            let _: EmptyResponse = try await request(
                "/auth/session/touch",
                method: "POST",
                token: token
            )
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
            userID: response.userID,
            expiresIn: TimeInterval(response.expiresIn)
        )
        userID = response.userID
        avatarURL = AppConfig.resolveMediaURL(response.avatarURL)
        trainingStage = Experience(rawValue: response.trainingStage ?? "") ?? .beginner
        onboardingRequired = response.onboardingRequired
        isAuthenticated = true
    }

    private func clearSession() {
        WatchSyncManager.shared.resetForLogout()
        AuthTokenStore.shared.clear()
        userID = nil
        phone = nil
        avatarURL = nil
        trainingStage = .beginner
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
        avatarURL = AppConfig.resolveMediaURL(response.avatarURL)
        trainingStage = Experience(rawValue: response.trainingStage ?? "") ?? .beginner
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
        request.setValue(DeviceIdentity.current, forHTTPHeaderField: "X-Device-ID")
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
                // Release 不暴露开发服务器；保留 Debug 提示用于真机联调。
                #if DEBUG
                let message = "无法连接服务端。请确认后端已启动；真机调试时请在登录页「开发服务器」填写电脑的局域网地址。"
                #else
                let message = "无法连接服务端，请检查网络后重试。"
                #endif
                throw AuthError(message: message)
            }
            throw AuthError(message: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError(message: "网络响应异常")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.errorMessage(from: data)
            throw AuthError(message: message, statusCode: http.statusCode)
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
    var statusCode: Int? = nil
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
    let avatarURL: String?
    let trainingStage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case isNewUser = "is_new_user"
        case onboardingRequired = "onboarding_required"
        case avatarURL = "avatar_url"
        case trainingStage = "training_stage"
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
    let avatarURL: String?
    let trainingStage: String?
    let onboardingRequired: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case phone
        case avatarURL = "avatar_url"
        case trainingStage = "training_stage"
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
