import Foundation

/// One sex-matched exercise demo clip returned by the media service.
struct ExerciseMediaItem: Decodable, Equatable, Identifiable {
    let exerciseSlug: String
    let sex: String
    let phoneURL: URL?
    let posterURL: URL?
    let watchURL: URL?
    let durationSeconds: Int?
    let loopStartMS: Int?
    let loopEndMS: Int?
    let version: Int

    var id: String { exerciseSlug }

    enum CodingKeys: String, CodingKey {
        case exerciseSlug = "exercise_slug"
        case sex
        case phoneURL = "phone_url"
        case posterURL = "poster_url"
        case watchURL = "watch_url"
        case durationSeconds = "duration_seconds"
        case loopStartMS = "loop_start_ms"
        case loopEndMS = "loop_end_ms"
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseSlug = try container.decode(String.self, forKey: .exerciseSlug)
        sex = try container.decodeIfPresent(String.self, forKey: .sex) ?? "unisex"
        phoneURL = AppConfig.resolveMediaURL(
            try container.decodeIfPresent(String.self, forKey: .phoneURL)
        )
        posterURL = AppConfig.resolveMediaURL(
            try container.decodeIfPresent(String.self, forKey: .posterURL)
        )
        watchURL = AppConfig.resolveMediaURL(
            try container.decodeIfPresent(String.self, forKey: .watchURL)
        )
        durationSeconds = try container.decodeIfPresent(
            Int.self,
            forKey: .durationSeconds
        )
        loopStartMS = try container.decodeIfPresent(
            Int.self,
            forKey: .loopStartMS
        )
        loopEndMS = try container.decodeIfPresent(
            Int.self,
            forKey: .loopEndMS
        )
        version = try container.decodeIfPresent(
            Int.self,
            forKey: .version
        ) ?? 1
    }
}

struct ExerciseMediaList: Decodable {
    let items: [ExerciseMediaItem]
}
