import Foundation
import Security
import FitAIWorkoutCore

struct WatchRuntimeConfig: Codable, Hashable {
    var apiBaseURL: String
    var userID: String?
}

/// Keychain-backed watch credentials. The access/refresh tokens never live in
/// UserDefaults or a plain file, and the phone-specific session is replaced by
/// a dedicated watch session during preload.
@MainActor
final class WatchCredentialStore {
    static let shared = WatchCredentialStore()

    private let service = "com.fitai.watch.auth"
    private let authKey = "watch_auth"
    private let runtimeKey = "watch_runtime"

    private init() {}

    var auth: WatchAuth? {
        guard let data = read(authKey) else { return nil }
        return try? JSONDecoder().decode(WatchAuth.self, from: data)
    }

    var runtime: WatchRuntimeConfig? {
        guard let data = read(runtimeKey) else { return nil }
        return try? JSONDecoder().decode(WatchRuntimeConfig.self, from: data)
    }

    var apiBaseURL: URL? {
        guard let raw = runtime?.apiBaseURL, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    func apply(
        apiBaseURL: String?,
        userID: String?,
        auth: WatchAuth?
    ) {
        if let apiBaseURL, !apiBaseURL.isEmpty {
            let runtime = WatchRuntimeConfig(
                apiBaseURL: apiBaseURL,
                userID: userID
            )
            if let data = try? JSONEncoder().encode(runtime) {
                write(runtimeKey, data: data)
            }
        }
        if let auth {
            if let data = try? JSONEncoder().encode(auth) {
                write(authKey, data: data)
            }
        }
    }

    func update(auth: WatchAuth) {
        if let data = try? JSONEncoder().encode(auth) {
            write(authKey, data: data)
        }
    }

    func clearAuth() {
        delete(authKey)
        guard var runtime else { return }
        runtime.userID = nil
        if let data = try? JSONEncoder().encode(runtime) {
            write(runtimeKey, data: data)
        }
    }

    func clearAll() {
        delete(authKey)
        delete(runtimeKey)
    }

    private func query(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    private func read(_ key: String) -> Data? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
        else {
            return nil
        }
        return result as? Data
    }

    private func write(_ key: String, data: Data) {
        delete(key)
        var attributes = query(key)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func delete(_ key: String) {
        SecItemDelete(query(key) as CFDictionary)
    }
}
