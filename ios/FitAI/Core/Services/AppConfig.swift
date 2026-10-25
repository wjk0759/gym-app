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

    static let useRemoteAI = false
    static let appVersion = "0.1.0"
}
