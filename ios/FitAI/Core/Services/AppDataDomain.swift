import Foundation

/// Data areas affected by a coach write. The server returns these as
/// `refresh_domains`; the app re-fetches each area instead of guessing what
/// changed.
enum AppDataDomain: String, CaseIterable, Hashable {
    case plan
    case schedule
    case workouts
    case diet
    case body
    case profile
    case equipment
    case review
    case inbox
}
