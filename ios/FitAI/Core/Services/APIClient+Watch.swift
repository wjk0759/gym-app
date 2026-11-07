import Foundation
import FitAIWorkoutCore

struct RemoteWatchBootstrap: Decodable {
    let serverTime: Date
    let access: AccessSnapshot
    let programDay: RemoteWatchDay
    let media: [RemoteWatchMedia]

    enum CodingKeys: String, CodingKey {
        case serverTime = "server_time"
        case access
        case programDay = "program_day"
        case media
    }
}

struct RemoteWatchDay: Decodable {
    let id: UUID
    let title: String
    let exercises: [RemoteWatchExercise]

    var watchExercises: [WorkoutExercise] {
        exercises
            .sorted { ($0.orderIndex ?? 0) < ($1.orderIndex ?? 0) }
            .map(\.watchExercise)
    }
}

struct RemoteWatchExercise: Decodable {
    let id: UUID
    let slug: String
    let nameZH: String?
    let equipment: String?
    let sets: Int
    let reps: String
    let weightKG: Double?
    let restSec: Int
    let rpe: Double?
    let orderIndex: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case nameZH = "name_zh"
        case equipment
        case sets
        case reps
        case weightKG = "weight_kg"
        case restSec = "rest_sec"
        case rpe
        case orderIndex = "order_index"
    }

    var watchExercise: WorkoutExercise {
        let name = (nameZH?.isEmpty == false ? nameZH! : slug)
        let unilateralHints = ["单腿", "单臂", "单侧", "每侧", "交替"]
        return WorkoutExercise(
            id: id,
            slug: slug,
            name: name,
            target: Self.target(from: reps),
            sets: max(1, sets),
            weightKG: weightKG,
            restSeconds: max(0, restSec),
            isBodyweight: equipment == "bodyweight",
            isUnilateral: unilateralHints.contains {
                name.contains($0) || reps.contains($0)
            },
            equipment: equipment
        )
    }

    private static func target(from raw: String) -> WorkoutExercise.Target {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let timed = text.contains("秒")
            || lower.contains("sec")
            || lower.range(of: #"\d+\s*s$"#, options: .regularExpression) != nil
        let numbers = text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        if timed {
            return .time(seconds: max(1, numbers.first ?? 30))
        }
        if numbers.count >= 2 {
            let lower = max(1, numbers[0])
            let upper = max(lower, numbers[1])
            return .reps(min: lower, max: upper)
        }
        let value = max(1, numbers.first ?? 10)
        return .reps(min: value, max: value)
    }
}

struct RemoteWatchMedia: Decodable {
    let exerciseSlug: String
    let sex: String
    let watchURL: String?
    let phoneURL: String?
    let posterURL: String?
    let durationSeconds: Int?
    let loopStartMS: Int?
    let loopEndMS: Int?
    let sha256: String?
    let version: Int

    enum CodingKeys: String, CodingKey {
        case exerciseSlug = "exercise_slug"
        case sex
        case watchURL = "watch_url"
        case phoneURL = "phone_url"
        case posterURL = "poster_url"
        case durationSeconds = "duration_seconds"
        case loopStartMS = "loop_start_ms"
        case loopEndMS = "loop_end_ms"
        case sha256
        case version
    }

    func asset(resolvingAgainst baseURL: URL?) -> WatchMediaAsset {
        WatchMediaAsset(
            exerciseSlug: exerciseSlug,
            sex: sex,
            watchURL: resolve(watchURL, baseURL: baseURL),
            phoneURL: resolve(phoneURL, baseURL: baseURL),
            posterURL: resolve(posterURL, baseURL: baseURL),
            durationSeconds: durationSeconds,
            loopStartMS: loopStartMS,
            loopEndMS: loopEndMS,
            sha256: sha256,
            version: version
        )
    }

    private func resolve(_ raw: String?, baseURL: URL?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        guard let baseURL else { return URL(string: raw) }
        var components = URLComponents(
            url: baseURL,
            resolvingAgainstBaseURL: false
        )
        var basePath = components?.path ?? ""
        if basePath.hasSuffix("/api/v1") {
            basePath.removeLast("/api/v1".count)
        }
        components?.path = basePath + (raw.hasPrefix("/") ? raw : "/" + raw)
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
}

struct WatchSessionCredentials: Decodable {
    let userID: String
    let deviceID: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: TimeInterval

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case deviceID = "device_id"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    func auth(now: Date = Date()) -> WatchAuth {
        WatchAuth(
            userID: userID,
            deviceID: deviceID,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: now.addingTimeInterval(expiresIn)
        )
    }
}

extension APIClient {
    func fetchWatchBootstrap(dayID: UUID) async throws -> RemoteWatchBootstrap {
        try await send(
            path: "watch/bootstrap?day_id=\(dayID.uuidString.lowercased())",
            method: "GET",
            body: nil,
            timeout: 30
        )
    }

    func revokeWatchSessions() async throws {
        _ = try await transport.perform(
            path: "watch/session",
            method: "DELETE",
            body: nil,
            timeout: 8
        )
    }

    func createWatchSession(
        deviceID: String,
        deviceName: String = "Apple Watch"
    ) async throws -> WatchSessionCredentials {
        let body = try JSONSerialization.data(withJSONObject: [
            "device_id": deviceID,
            "device_name": deviceName
        ])
        return try await send(
            path: "watch/session",
            method: "POST",
            body: body,
            timeout: 30
        )
    }
}
