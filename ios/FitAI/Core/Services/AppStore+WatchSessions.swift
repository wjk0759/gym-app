import Foundation
import FitAIWorkoutCore

extension PlanExercise {
    init(watch exercise: WorkoutExercise) {
        let reps: String
        switch exercise.target {
        case .reps(let min, let max):
            reps = min == max ? "\(min)" : "\(min)-\(max)"
        case .time(let seconds):
            reps = "\(seconds)秒"
        }
        self.init(
            id: exercise.id,
            slug: exercise.slug,
            sets: exercise.sets,
            reps: reps,
            weightKG: exercise.weightKG,
            restSec: exercise.restSeconds,
            rpe: 7.5
        )
    }
}

extension AppStore {
    /// Merge a watch snapshot that arrived while the workout screen was not
    /// open. Finished sessions are recorded exactly once using the watch
    /// session UUID; active sessions restore the phone draft.
    @discardableResult
    func ingestWatchEnvelope(_ envelope: WatchSessionEnvelope) -> Bool {
        guard AuthTokenStore.shared.userID != nil else { return false }
        if let userID = envelope.userID,
           userID != AuthTokenStore.shared.userID {
            return false
        }

        let snapshot = envelope.snapshot
        let logs = snapshot.sets.map { SetLog(record: $0) }

        switch snapshot.status {
        case .discarded:
            clearWorkoutDraft(dayID: snapshot.programDayID)
            return true
        case .finished:
            guard !logs.isEmpty else {
                clearWorkoutDraft(dayID: snapshot.programDayID)
                return true
            }
            if sessions.contains(where: { $0.id == envelope.sessionID }) {
                clearWorkoutDraft(dayID: snapshot.programDayID)
                return true
            }
            var sessionDay = plan?.days.first(where: {
                $0.id == snapshot.programDayID
            }) ?? PlanDay(
                id: snapshot.programDayID,
                weekday: 1,
                title: snapshot.dayTitle,
                focus: [],
                exercises: []
            )
            sessionDay.exercises = snapshot.exercises.map {
                PlanExercise(watch: $0)
            }
            let end = snapshot.finishedAt ?? Date()
            let duration = max(
                1,
                Int(end.timeIntervalSince(snapshot.startedAt) / 60)
            )
            record(
                day: sessionDay,
                sets: logs,
                durationMinutes: duration,
                feeling: 3,
                notes: nil,
                plannedSets: snapshot.plannedSetCount,
                sessionID: envelope.sessionID,
                endedAt: end
            )
            clearWorkoutDraft(dayID: snapshot.programDayID)
            return true
        case .active, .paused:
            guard var sessionDay = plan?.days.first(where: {
                $0.id == snapshot.programDayID
            }) else {
                return false
            }
            sessionDay.exercises = snapshot.exercises.map {
                PlanExercise(watch: $0)
            }
            let draft = WorkoutDraft(
                dayID: snapshot.programDayID,
                dayTitle: snapshot.dayTitle,
                logs: logs,
                currentIndex: min(
                    snapshot.currentExerciseIndex,
                    sessionDay.exercises.count
                ),
                plannedSets: snapshot.plannedSetCount,
                elapsedSeconds: max(
                    0,
                    Date().timeIntervalSince(snapshot.startedAt)
                ),
                feeling: 3,
                notes: "",
                adjustedExercises: [],
                exercises: sessionDay.exercises
            )
            saveWorkoutDraft(draft, persistImmediately: true)
            return true
        }
    }
}
