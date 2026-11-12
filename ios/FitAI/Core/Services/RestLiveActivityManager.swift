import ActivityKit
import Foundation

/// Owns the one rest Live Activity. The countdown itself is rendered by the
/// widget from `startDate...endDate`, so the app only starts, updates and ends
/// the activity at rest boundaries.
@MainActor
final class RestLiveActivityManager {
    static let shared = RestLiveActivityManager()

    private var activity: Activity<RestTimerAttributes>?

    private init() {}

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(
        sessionID: String,
        dayTitle: String,
        exerciseName: String,
        setLabel: String,
        startDate: Date,
        endDate: Date,
        totalSeconds: Int
    ) async {
        guard areActivitiesEnabled, endDate > Date() else { return }

        let state = RestTimerAttributes.ContentState(
            startDate: startDate,
            endDate: endDate,
            totalSeconds: max(1, totalSeconds),
            exerciseName: exerciseName,
            setLabel: setLabel
        )
        let content = ActivityContent(state: state, staleDate: endDate)

        if let current = activity,
           current.attributes.sessionID == sessionID {
            await current.update(content)
            return
        }

        await endAll()

        if let existing = Activity<RestTimerAttributes>.activities
            .first(where: { $0.attributes.sessionID == sessionID }) {
            activity = existing
            await existing.update(content)
            return
        }

        do {
            activity = try Activity.request(
                attributes: RestTimerAttributes(
                    dayTitle: dayTitle,
                    sessionID: sessionID
                ),
                content: content,
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func end(sessionID: String) async {
        for item in Activity<RestTimerAttributes>.activities
        where item.attributes.sessionID == sessionID {
            await item.end(nil, dismissalPolicy: .immediate)
        }
        if activity?.attributes.sessionID == sessionID {
            activity = nil
        }
    }

    func endAll() async {
        for item in Activity<RestTimerAttributes>.activities {
            await item.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    /// Used when the user turns the island back on while a rest is already
    /// running, and after the workout screen restores a draft.
    func resumeFromDraftIfNeeded(
        draft: WorkoutDraft?,
        dayTitle: String
    ) async {
        guard areActivitiesEnabled,
              let draft,
              let endDate = draft.restEndDate,
              endDate > Date() else {
            return
        }

        let total = max(
            1,
            draft.restTotalSeconds ?? Int(endDate.timeIntervalSinceNow)
        )
        let startDate = endDate.addingTimeInterval(-TimeInterval(total))
        let exercises = draft.exercises ?? []
        let index = min(max(0, draft.currentIndex), max(0, exercises.count - 1))
        let exerciseName = exercises.indices.contains(index)
            ? exercises[index].displayName
            : "休息"

        await start(
            sessionID: draft.dayID.uuidString,
            dayTitle: dayTitle,
            exerciseName: exerciseName,
            setLabel: "",
            startDate: startDate,
            endDate: endDate,
            totalSeconds: total
        )
    }
}
