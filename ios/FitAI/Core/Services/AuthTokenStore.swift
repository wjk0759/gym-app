import Foundation
import Security

/// 只负责把登录态放进 Keychain，避免把 token 写进 UserDefaults 或明文文件。
final class AuthTokenStore {
    static let shared = AuthTokenStore()

    private let service = "com.fitai.app.auth"
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    private let userKey = "user_id"
    private let expiryKey = "access_expires_at"
    private let lock = NSLock()

    // Keychain 查询比内存读取慢；网络请求每次都会读取 token，因此缓存一份。
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?
    private var cachedUserID: String?
    private var cachedAccessExpiry: Date?

    private init() {
        cachedAccessToken = read(accessKey)
        cachedRefreshToken = read(refreshKey)
        cachedUserID = read(userKey)
        cachedAccessExpiry = read(expiryKey).flatMap {
            ISO8601DateFormatter().date(from: $0)
        }
    }

    var accessToken: String? { withLock { cachedAccessToken } }
    var refreshToken: String? { withLock { cachedRefreshToken } }
    var userID: String? { withLock { cachedUserID } }
    var accessExpiresAt: Date? { withLock { cachedAccessExpiry } }

    func save(
        accessToken: String,
        refreshToken: String,
        userID: String,
        expiresIn: TimeInterval
    ) {
        let expiry = Date().addingTimeInterval(expiresIn)
        write(accessKey, value: accessToken)
        write(refreshKey, value: refreshToken)
        write(userKey, value: userID)
        write(expiryKey, value: ISO8601DateFormatter().string(from: expiry))
        withLock {
            cachedAccessToken = accessToken
            cachedRefreshToken = refreshToken
            cachedUserID = userID
            cachedAccessExpiry = expiry
        }
    }

    func updateTokens(accessToken: String, refreshToken: String, expiresIn: TimeInterval) {
        let expiry = Date().addingTimeInterval(expiresIn)
        write(accessKey, value: accessToken)
        write(refreshKey, value: refreshToken)
        write(expiryKey, value: ISO8601DateFormatter().string(from: expiry))
        withLock {
            cachedAccessToken = accessToken
            cachedRefreshToken = refreshToken
            cachedAccessExpiry = expiry
        }
    }

    func clear() {
        delete(accessKey)
        delete(refreshKey)
        delete(userKey)
        delete(expiryKey)
        withLock {
            cachedAccessToken = nil
            cachedRefreshToken = nil
            cachedUserID = nil
            cachedAccessExpiry = nil
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    private func read(_ key: String) -> String? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ key: String, value: String) {
        delete(key)
        var attributes = query(key)
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}

extension Notification.Name {
    /// Posted when the server definitively rejects the refresh token
    /// (expired, revoked, or device mismatch). The UI must return to login.
    static let fitaiSessionExpired = Notification.Name("fitai.session.expired")
}
