import Foundation

/// Per-exercise load helpers for the coach's plan-adjustment flow.
/// Keeping these out of PlanAdjustmentCoach.swift avoids pushing the main
/// conversation file past the SwiftLint length limit.
extension AppStore {
    func recentWeightMultipliers(_ multiplier: Double) -> [String: Double] {
        guard let plan else { return [:] }
        let history = LoadProgression.history(from: sessions)
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        var result: [String: Double] = [:]
        for day in plan.days {
            for item in day.exercises {
                guard let performance = history[item.slug] else { continue }
                if let cutoff, performance.lastDate < cutoff { continue }
                result[item.slug] = multiplier
            }
        }
        return result
    }

    func painWeightMultipliers(
        painMuscle: MuscleGroup?,
        avoidSlugs: [String]
    ) -> [String: Double] {
        guard let plan else { return [:] }
        var result: [String: Double] = [:]
        for day in plan.days {
            for item in day.exercises {
                if avoidSlugs.contains(item.slug)
                    || (painMuscle != nil && item.exercise?.muscle == painMuscle) {
                    result[item.slug] = 0.9
                }
            }
        }
        if painMuscle == nil, avoidSlugs.isEmpty {
            for day in plan.days {
                for item in day.exercises {
                    result[item.slug] = 0.9
                }
            }
        }
        return result
    }

    func plateauWeightMultipliers() -> [String: Double] {
        guard let plan else { return [:] }
        let history = LoadProgression.history(from: sessions)
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        var result: [String: Double] = [:]
        for day in plan.days {
            for item in day.exercises {
                guard let performance = history[item.slug] else { continue }
                if let cutoff, performance.lastDate < cutoff { continue }
                let range = LoadProgression.parseRepRange(item.reps)
                let rpe = performance.lastRPE ?? 0
                let rpeOK = rpe == 0
                    || rpe <= LoadProgression.stageRPE(profile.trainingStage)
                guard performance.lastReps >= range.lowerBound, rpeOK else { continue }
                let lower = item.exercise?.muscle == .legs
                    || item.exercise?.muscle == .glutes
                let upperStep = profile.trainingStage == .advanced ? 0.0125 : 0.025
                let lowerStep = profile.trainingStage == .advanced ? 0.025 : 0.05
                result[item.slug] = 1 + (lower ? lowerStep : upperStep)
            }
        }
        return result
    }
}
