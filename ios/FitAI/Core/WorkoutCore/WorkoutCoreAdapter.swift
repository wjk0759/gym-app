import Foundation
import FitAIWorkoutCore

/// Bridges the existing app models into the shared, platform-neutral workout
/// core. Keeping this in one file prevents SwiftUI views from growing their own
/// ad-hoc snapshot code and gives watchOS a single serialization contract.
extension WorkoutExercise {
    init(planExercise: PlanExercise) {
        let exercise = planExercise.exercise
        let name = planExercise.displayName
        let target = Self.target(from: planExercise.reps)
        let unilateralHints = ["单腿", "单臂", "单侧", "每侧", "交替"]
        let isUnilateral = unilateralHints.contains { hint in
            name.contains(hint) || planExercise.reps.contains(hint)
        }

        self.init(
            id: planExercise.id,
            slug: planExercise.slug,
            name: name,
            target: target,
            sets: planExercise.sets,
            weightKG: planExercise.weightKG,
            restSeconds: planExercise.restSec,
            isBodyweight: exercise?.equipment == .bodyweight,
            isUnilateral: isUnilateral,
            equipment: exercise?.equipment.label
        )
    }

    private static func target(from raw: String) -> Target {
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

extension WorkoutSessionSnapshot {
    init(
        day: PlanDay,
        startedAt: Date = Date(),
        leaderDeviceID: UUID? = nil
    ) {
        self.init(
            programDayID: day.id,
            dayTitle: day.title,
            startedAt: startedAt,
            exercises: day.exercises.map { WorkoutExercise(planExercise: $0) },
            leaderDeviceID: leaderDeviceID
        )
    }
}

extension SetLog {
    init(record: WorkoutSetRecord) {
        self.init(
            id: record.id,
            slug: record.exerciseSlug,
            setIndex: record.setIndex,
            weightKG: record.weightKG,
            reps: record.reps ?? 0,
            rpe: record.rpe ?? 7.5,
            completed: true
        )
    }
}
