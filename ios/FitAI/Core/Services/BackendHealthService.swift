import Foundation

/// 后端健康检查的轻量封装，仅用于设置页/诊断。
enum BackendHealthService {
    static func status() async throws -> HealthStatus {
        try await APIClient.shared.healthStatus()
    }
}
