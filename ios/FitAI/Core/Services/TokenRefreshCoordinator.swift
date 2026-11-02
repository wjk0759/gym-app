import Foundation

/// Single-flight refresh. Concurrent 401s share one rotation request; a burst
/// of API calls can never rotate the same refresh token twice.
actor TokenRefreshCoordinator {
    static let shared = TokenRefreshCoordinator()

    private var inFlight: Task<Bool, Never>?

    func refresh() async -> Bool {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await Self.performRefresh() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    private static func performRefresh() async -> Bool {
        guard let refreshToken = AuthTokenStore.shared.refreshToken,
              let url = URL(string: AppConfig.apiBaseURL.absoluteString + "/auth/refresh") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(DeviceIdentity.current, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "refresh_token": refreshToken
        ])
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            guard (200..<300).contains(http.statusCode) else {
                // A 401/403 is definitive: the refresh token is expired,
                // revoked, or bound to another device. Clear it and ask the
                // user to sign in again; transient/network failures keep the
                // local session so offline usage is not destroyed.
                if http.statusCode == 401 || http.statusCode == 403 {
                    AuthTokenStore.shared.clear()
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .fitaiSessionExpired,
                            object: nil
                        )
                    }
                }
                return false
            }
            let decoded = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            AuthTokenStore.shared.updateTokens(
                accessToken: decoded.accessToken,
                refreshToken: decoded.refreshToken,
                expiresIn: TimeInterval(decoded.expiresIn ?? 1800)
            )
            return true
        } catch {
            return false
        }
    }
}
