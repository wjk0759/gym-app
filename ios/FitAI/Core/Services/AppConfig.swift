import Foundation

enum AppConfig {
    private static let defaultAPIBaseURL: URL = {
#if DEBUG
        URL(string: "http://127.0.0.1:8000/api/v1")!
#else
        // 生产域名通过 project.yml 的 FITAI_API_BASE_URL 注入 Info.plist。
        // 这里故意使用保留的 .invalid 域名，避免 Release 包静默连 localhost。
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FitAIAPIBaseURL") as? String,
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https" else {
            return URL(string: "https://api.invalid/api/v1")!
        }
        return url
#endif
    }()
    private static let apiBaseKey = "fitai_api_base_url"

    /// Debug 构建可在登录页「开发服务器」里改成电脑局域网 IP；Release 固定用生产域名。
    static var apiBaseURL: URL {
#if DEBUG
        if let value = UserDefaults.standard.string(forKey: apiBaseKey),
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }
#endif
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

    /// 免费个人团队不支持 Sign in with Apple。Debug 真机测试隐藏入口，
    /// Release 仍保留 Apple 登录与正式 entitlement。
    static var appleSignInEnabled: Bool {
#if DEBUG
        false
#else
        true
#endif
    }

    /// 教学视频素材尚未上线，先隐藏所有视频入口。
    /// 接入素材后改回 true；不要删除 EquipmentDetailView+Media.swift 里的播放器/占位代码。
    static let exerciseVideosEnabled = false

    static let appVersion = "0.1.0"
}
