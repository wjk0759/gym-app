import Foundation

enum BackendHealthService {
    static func status() async throws -> HealthStatus {
        try await APIClient.shared.healthStatus()
    }
}
