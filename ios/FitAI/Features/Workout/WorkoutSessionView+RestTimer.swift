import FitAIWorkoutCore
import SwiftUI

extension WorkoutSessionView {
    static func restRemaining(until endDate: Date, now: Date = Date()) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(now))))
    }

    var restNotificationID: String {
        "rest-\(day.id.uuidString)"
    }

    func startRest(seconds: Int, exercise: PlanExercise) {
        guard seconds > 0 else {
            endRest()
            return
        }

        let startDate = Date()
        let endDate = startDate.addingTimeInterval(TimeInterval(seconds))
        restEndDate = endDate
        restTotal = Double(seconds)
        restRemaining = seconds

        if store.restLiveActivityEnabled {
            let completed = completedSets(for: exercise)
            let setLabel = completed < exercise.sets
                ? "下一组 \(completed + 1)"
                : "本动作完成"
            Task {
                await RestLiveActivityManager.shared.start(
                    sessionID: day.id.uuidString,
                    dayTitle: activeDay.title,
                    exerciseName: exercise.displayName,
                    setLabel: setLabel,
                    startDate: startDate,
                    endDate: endDate,
                    totalSeconds: seconds
                )
            }
        }

        if scenePhase != .active {
            scheduleRestNotificationIfNeeded()
        }
    }

    func tickRest() {
        if let endDate = restEndDate {
            let remaining = Self.restRemaining(until: endDate)
            if remaining <= 0 {
                let endedRecently = Date().timeIntervalSince(endDate) < 2
                endRest(notifyHaptic: endedRecently)
            } else {
                restRemaining = remaining
            }
            return
        }

        // Watch-led sessions update this value from the watch snapshot; keep
        // the old countdown behavior when there is no phone-owned end date.
        guard let remaining = restRemaining else { return }
        if remaining <= 1 {
            restRemaining = nil
            if scenePhase == .active {
                Haptics.warning()
            }
        } else {
            restRemaining = remaining - 1
        }
    }

    func skipRest() {
        if isWatchLed {
            let command = WorkoutCommand.skipRest(
                .init(at: Date(), source: .phone)
            )
            guard sendToWatch(command) else { return }
        }
        endRest()
    }

    func endRest(notifyHaptic: Bool = false) {
        restEndDate = nil
        restRemaining = nil
        NotificationScheduler.shared.cancelRestEnd(
            identifier: restNotificationID
        )
        Task {
            await RestLiveActivityManager.shared.end(
                sessionID: day.id.uuidString
            )
        }
        if notifyHaptic, scenePhase == .active {
            Haptics.warning()
        }
    }

    func scheduleRestNotificationIfNeeded() {
        guard scenePhase != .active,
              store.restNotificationsEnabled,
              let endDate = restEndDate,
              endDate > Date() else {
            return
        }
        NotificationScheduler.shared.scheduleRestEnd(
            at: endDate,
            identifier: restNotificationID,
            exerciseName: currentExercise?.displayName ?? ""
        )
    }

    func cancelRestNotification() {
        NotificationScheduler.shared.cancelRestEnd(
            identifier: restNotificationID
        )
    }

    func handleRestScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            scheduleRestNotificationIfNeeded()
        case .active:
            cancelRestNotification()
            tickRest()
        default:
            break
        }
    }

    func restoreRestFromDraft(_ draft: WorkoutDraft) {
        guard let endDate = draft.restEndDate, endDate > Date() else {
            restEndDate = nil
            restRemaining = nil
            cancelRestNotification()
            Task {
                await RestLiveActivityManager.shared.end(
                    sessionID: day.id.uuidString
                )
            }
            return
        }

        restEndDate = endDate
        restTotal = Double(
            max(1, draft.restTotalSeconds ?? Int(endDate.timeIntervalSinceNow))
        )
        restRemaining = Self.restRemaining(until: endDate)

        if store.restLiveActivityEnabled {
            Task {
                await RestLiveActivityManager.shared.resumeFromDraftIfNeeded(
                    draft: draft,
                    dayTitle: activeDay.title
                )
            }
        }
    }

    func handleRestLiveActivitySettingChange(_ enabled: Bool) {
        if !enabled {
            Task {
                await RestLiveActivityManager.shared.end(
                    sessionID: day.id.uuidString
                )
            }
            return
        }

        guard let endDate = restEndDate,
              endDate > Date(),
              let exercise = currentExercise else {
            return
        }
        let startDate = endDate.addingTimeInterval(-restTotal)
        Task {
            await RestLiveActivityManager.shared.start(
                sessionID: day.id.uuidString,
                dayTitle: activeDay.title,
                exerciseName: exercise.displayName,
                setLabel: "",
                startDate: startDate,
                endDate: endDate,
                totalSeconds: Int(restTotal)
            )
        }
    }

    func handleRestNotificationSettingChange(_ enabled: Bool) {
        if enabled {
            scheduleRestNotificationIfNeeded()
        } else {
            cancelRestNotification()
        }
    }
}
