import Foundation

enum AppConfig {
    /// 模拟器连本机后端；真机改成电脑局域网 IP，例如 http://192.168.1.20:8000/api/v1
    static let apiBaseURL = URL(string: "http://127.0.0.1:8000/api/v1")!
    static let useRemoteAI = false
    static let appVersion = "0.1.0"
}
