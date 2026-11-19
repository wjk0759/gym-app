import Foundation

/// 云偏好/训练草稿 API。只做请求和映射，合并策略在 AppStore。
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

    func fetchWorkoutDraft() async throws -> RemoteWorkoutDraft? {
        let data: Data = try await send(
            path: "workouts/draft",
            method: "GET",
            body: nil
        )
        return try decode(RemoteWorkoutDraftEnvelope.self, from: data).draft
    }

    func pushWorkoutDraft(_ draft: WorkoutDraft) async throws -> RemoteWorkoutDraft? {
        let payloadData = try JSONEncoder().encode(draft)
        let payload = try JSONSerialization.jsonObject(with: payloadData)
        let body = try JSONSerialization.data(
            withJSONObject: [
                "day_id": draft.dayID.uuidString.lowercased(),
                "updated_at": APIDateCoding.iso8601WithFractionalSeconds.string(
                    from: draft.updatedAt
                ),
                "payload": payload,
            ]
        )
        let data: Data = try await send(
            path: "workouts/draft",
            method: "PUT",
            body: body
        )
        return try decode(RemoteWorkoutDraftEnvelope.self, from: data).draft
    }

    func deleteWorkoutDraft(dayID: UUID) async throws {
        try await sendVoid(
            path: "workouts/draft?day_id=\(dayID.uuidString.lowercased())",
            method: "DELETE",
            body: nil
        )
    }
}
