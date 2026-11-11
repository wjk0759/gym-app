import Foundation

/// One sex-matched exercise demo clip returned by the media service.
/// An exercise can now have several variants (different models / visual styles);
/// each carries its own `media_id` and visual priority.
struct ExerciseMediaItem: Decodable, Equatable, Identifiable {
    let exerciseSlug: String
    let mediaID: String?
    let sex: String
    let phoneURL: URL?
    let posterURL: URL?
    let watchURL: URL?
    let durationSeconds: Int?
    let loopStartMS: Int?
    let loopEndMS: Int?
    let version: Int
    let visualStyle: String?
    let visualPriority: Int?
    let isPrimaryForWatch: Bool

    var id: String { mediaID ?? exerciseSlug }

    init(
        exerciseSlug: String,
        mediaID: String? = nil,
        sex: String = "unisex",
        phoneURL: URL?,
        posterURL: URL?,
        watchURL: URL? = nil,
        durationSeconds: Int? = nil,
        loopStartMS: Int? = nil,
        loopEndMS: Int? = nil,
        version: Int = 1,
        visualStyle: String? = nil,
        visualPriority: Int? = nil,
        isPrimaryForWatch: Bool = false
    ) {
        self.exerciseSlug = exerciseSlug
        self.mediaID = mediaID
        self.sex = sex
        self.phoneURL = phoneURL
        self.posterURL = posterURL
        self.watchURL = watchURL
        self.durationSeconds = durationSeconds
        self.loopStartMS = loopStartMS
        self.loopEndMS = loopEndMS
        self.version = version
        self.visualStyle = visualStyle
        self.visualPriority = visualPriority
        self.isPrimaryForWatch = isPrimaryForWatch
    }

    init(
        exerciseSlug: String,
        localVariant variant: ExerciseMediaVariant,
        index: Int
    ) {
        self.init(
            exerciseSlug: exerciseSlug,
            mediaID: "local-\(exerciseSlug)-\(index)",
            sex: "unisex",
            phoneURL: variant.videoURL,
            posterURL: variant.posterURL,
            visualStyle: variant.visualStyle,
            visualPriority: 1000 + index,
            isPrimaryForWatch: false
        )
    }

    enum CodingKeys: String, CodingKey {
        case exerciseSlug = "exercise_slug"
        case mediaID = "media_id"
        case sex
        case phoneURL = "phone_url"
        case posterURL = "poster_url"
        case watchURL = "watch_url"
        case durationSeconds = "duration_seconds"
        case loopStartMS = "loop_start_ms"
        case loopEndMS = "loop_end_ms"
        case version
        case visualStyle = "visual_style"
        case visualPriority = "visual_priority"
        case isPrimaryForWatch = "is_primary_for_watch"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exerciseSlug = try container.decode(String.self, forKey: .exerciseSlug)
        mediaID = try container.decodeIfPresent(String.self, forKey: .mediaID)
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
        visualStyle = try container.decodeIfPresent(
            String.self,
            forKey: .visualStyle
        )
        visualPriority = try container.decodeIfPresent(
            Int.self,
            forKey: .visualPriority
        )
        isPrimaryForWatch = try container.decodeIfPresent(
            Bool.self,
            forKey: .isPrimaryForWatch
        ) ?? false
    }
}

struct ExerciseMediaList: Decodable {
    let items: [ExerciseMediaItem]
}
