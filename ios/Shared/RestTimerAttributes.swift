import ActivityKit
import Foundation

/// Shared between the app (which starts/updates the activity) and the widget
/// (which renders it). Keep this file free of app-only types so both targets
/// can compile it.
struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var totalSeconds: Int
        var exerciseName: String
        var setLabel: String
    }

    var dayTitle: String
    var sessionID: String
}
