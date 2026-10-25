import Foundation
import Security

/// 只负责把登录态放进 Keychain，避免把 token 写进 UserDefaults 或明文文件。
final class AuthTokenStore {
    static let shared = AuthTokenStore()

    private let service = "com.fitai.app.auth"
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"
    private let userKey = "user_id"

    private init() {}

    var accessToken: String? { read(accessKey) }
    var refreshToken: String? { read(refreshKey) }
    var userID: String? { read(userKey) }

    func save(accessToken: String, refreshToken: String, userID: String) {
        write(accessKey, value: accessToken)
        write(refreshKey, value: refreshToken)
        write(userKey, value: userID)
    }

    func updateTokens(accessToken: String, refreshToken: String) {
        write(accessKey, value: accessToken)
        write(refreshKey, value: refreshToken)
    }

    func clear() {
        delete(accessKey)
        delete(refreshKey)
        delete(userKey)
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
