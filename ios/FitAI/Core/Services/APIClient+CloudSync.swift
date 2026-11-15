import Foundation

extension APIClient {
    func fetchCloudSync() async throws -> RemoteCloudSync {
        let data: Data = try await send(path: "sync", method: "GET", body: nil)
        return try decode(RemoteCloudSync.self, from: data)
    }

    func pushCloudSync(_ payload: [String: Any]) async throws -> RemoteCloudSync {
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data: Data = try await send(path: "sync", method: "POST", body: body)
        return try decode(RemoteCloudSync.self, from: data)
    }
}
