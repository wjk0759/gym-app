import Foundation

enum AppConfig {
    private static let defaultAPIBaseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
    private static let apiBaseKey = "fitai_api_base_url"

    /// 真机调试可在登录页「开发服务器」里改成电脑局域网 IP。
    static var apiBaseURL: URL {
        if let value = UserDefaults.standard.string(forKey: apiBaseKey),
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }
        return defaultAPIBaseURL
    }

    static var apiBaseURLString: String {
        apiBaseURL.absoluteString
    }

    static func setAPIBaseURL(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: apiBaseKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: apiBaseKey)
        }
    }

    /// Debug 构建默认打开远程 AI，方便 Mac/模拟器直接体验 DeepSeek；
    /// Release 仍由 Pro 权益控制，不会绕过付费门槛。
    static var useRemoteAI: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static var debugForceRemoteAI: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static let appVersion = "0.1.0"
}
