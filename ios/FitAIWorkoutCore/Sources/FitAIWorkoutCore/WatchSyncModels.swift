import Foundation

/// Payload sent from iPhone to Watch before the phone is left behind.
public struct WatchBootstrap: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var serverTime: Date
    public var programDayID: UUID
    public var dayTitle: String
    public var exercises: [WorkoutExercise]
    public var media: [WatchMediaAsset]
    public var access: WatchAccess

    public init(
        generatedAt: Date = Date(),
        serverTime: Date,
        programDayID: UUID,
        dayTitle: String,
        exercises: [WorkoutExercise],
        media: [WatchMediaAsset],
        access: WatchAccess
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.generatedAt = generatedAt
        self.serverTime = serverTime
        self.programDayID = programDayID
        self.dayTitle = dayTitle
        self.exercises = exercises
        self.media = media
        self.access = access
    }
}

public struct WatchAccess: Codable, Hashable, Sendable {
    public var isPro: Bool
    public var proExpiresAt: Date?
    public var lastVerifiedAt: Date

    public init(
        isPro: Bool,
        proExpiresAt: Date?,
        lastVerifiedAt: Date = Date()
    ) {
        self.isPro = isPro
        self.proExpiresAt = proExpiresAt
        self.lastVerifiedAt = lastVerifiedAt
    }

    /// Three-day verification grace, hard-stopped by the subscription expiry.
    public func canTrain(at date: Date, graceDays: Int = 3) -> Bool {
        guard isPro else { return false }
        if let proExpiresAt, date > proExpiresAt { return false }
        let grace = TimeInterval(max(0, graceDays) * 24 * 60 * 60)
        return date <= lastVerifiedAt.addingTimeInterval(grace)
    }
}

public struct WatchMediaAsset: Codable, Hashable, Identifiable, Sendable {
    public var id: String { exerciseSlug }
    public var exerciseSlug: String
    public var sex: String
    public var watchURL: URL?
    public var phoneURL: URL?
    public var posterURL: URL?
    public var durationSeconds: Int?
    public var loopStartMS: Int?
    public var loopEndMS: Int?
    public var sha256: String?
    public var version: Int

    public init(
        exerciseSlug: String,
        sex: String,
        watchURL: URL? = nil,
        phoneURL: URL? = nil,
        posterURL: URL? = nil,
        durationSeconds: Int? = nil,
        loopStartMS: Int? = nil,
        loopEndMS: Int? = nil,
        sha256: String? = nil,
        version: Int
    ) {
        self.exerciseSlug = exerciseSlug
        self.sex = sex
        self.watchURL = watchURL
        self.phoneURL = phoneURL
        self.posterURL = posterURL
        self.durationSeconds = durationSeconds
        self.loopStartMS = loopStartMS
        self.loopEndMS = loopEndMS
        self.sha256 = sha256
        self.version = version
    }
}

/// Full-state sync envelope. Watch is authoritative during a watch-led
/// session; the phone applies this snapshot and queues it for the server.
public struct WatchSessionEnvelope: Codable, Hashable, Sendable {
    public var sessionID: UUID
    public var sentAt: Date
    public var snapshot: WorkoutSessionSnapshot

    public init(
        sessionID: UUID,
        sentAt: Date = Date(),
        snapshot: WorkoutSessionSnapshot
    ) {
        self.sessionID = sessionID
        self.sentAt = sentAt
        self.snapshot = snapshot
    }
}
