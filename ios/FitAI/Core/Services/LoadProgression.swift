import Foundation

/// Local mirror of the server's load progression rules.
/// The server remains authoritative for AI plans; this keeps the offline
/// fallback and the coach adjustment flow on the same policy.
enum LoadProgression {
    struct Performance: Equatable {
        var lastWeightKG: Double
        var lastReps: Int
        var lastRPE: Double?
        var lastDate: Date
        var sessionCount: Int
    }

    static func history(
        from sessions: [WorkoutSession],
        weeks: Int = 12
    ) -> [String: Performance] {
        let cutoff = Calendar.current.date(
            byAdding: .weekOfYear,
            value: -weeks,
            to: Date()
        ) ?? .distantPast
        let recent = sessions
            .filter { $0.date >= cutoff }
            .sorted { $0.date > $1.date }

        var result: [String: Performance] = [:]
        var counts: [String: Int] = [:]
        for session in recent {
            let grouped = Dictionary(
                grouping: session.sets.filter {
                    $0.completed && $0.weightKG > 0 && $0.reps > 0
                },
                by: \.slug
            )
            for (slug, sets) in grouped {
                counts[slug, default: 0] += 1
                guard result[slug] == nil else { continue }
                let working = sets.filter { (5...15).contains($0.reps) }
                let anchor = (working.isEmpty ? sets : working).max {
                    $0.weightKG == $1.weightKG
                        ? $0.reps < $1.reps
                        : $0.weightKG < $1.weightKG
                }
                guard let anchor else { continue }
                result[slug] = Performance(
                    lastWeightKG: anchor.weightKG,
                    lastReps: anchor.reps,
                    lastRPE: anchor.rpe,
                    lastDate: session.date,
                    sessionCount: 0
                )
            }
        }
        for slug in result.keys {
            result[slug]?.sessionCount = counts[slug] ?? 0
        }
        return result
    }

    static func parseRepRange(_ value: String?) -> ClosedRange<Int> {
        let numbers = (value ?? "")
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard let first = numbers.first else { return 8...10 }
        guard numbers.count > 1 else { return first...first }
        return min(first, numbers[1])...max(first, numbers[1])
    }

    static func targetWeight(
        exercise: Exercise,
        profile: UserProfile,
        history: Performance?,
        planWeightKG: Double? = nil,
        weekIndex: Int,
        reps: String?
    ) -> Double? {
        if exercise.equipment == .bodyweight { return nil }
        let range = parseRepRange(reps)
        let stage = profile.trainingStage
        var anchor: Double?
        var hasLog = false

        if let history {
            anchor = history.lastWeightKG
            if history.lastReps < range.lowerBound {
                let e1rm = history.lastWeightKG * (1 + Double(history.lastReps) / 30)
                let targetReps = Double(range.lowerBound + range.upperBound) / 2
                anchor = e1rm / (1 + targetReps / 30)
            }
            hasLog = anchor != nil
        } else if let planWeightKG, planWeightKG > 0 {
            anchor = planWeightKG
        }

        guard let anchor else {
            return estimateWeight(exercise, profile: profile)
        }
        let multiplier = weekMultiplier(
            stage: stage,
            weekIndex: weekIndex,
            lower: exercise.muscle == .legs || exercise.muscle == .glutes,
            compound: exercise.isCompound,
            hasLog: hasLog
        )
        return roundWeight(anchor * multiplier)
    }

    static func estimateWeight(
        exercise: Exercise,
        profile: UserProfile
    ) -> Double? {
        if exercise.equipment == .bodyweight { return nil }
        let factor: Double = switch profile.experience {
        case .beginner: 1.0
        case .intermediate: 1.5
        case .advanced: 2.0
        }

        if exercise.equipment == .barbell,
           exercise.isCompound,
           profile.weightKG > 0 {
            let experienceFactor: Double = switch profile.experience {
            case .beginner: 0.85
            case .intermediate: 1.0
            case .advanced: 1.15
            }
            return roundWeight(
                profile.weightKG * barbellRatio(exercise) * experienceFactor
            )
        }

        let base: Double = switch exercise.equipment {
        case .dumbbell: 8
        case .barbell: 20
        case .machine: 15
        case .cable: 10
        case .band: 5
        case .kettlebell: 8
        case .bodyweight: 0
        }
        let compoundFactor = exercise.isCompound ? 1.0 : 0.6
        return roundWeight(base * factor * compoundFactor)
    }

    static func stageRPE(_ stage: Experience) -> Double {
        switch stage {
        case .beginner: 7.5
        case .intermediate: 8
        case .advanced: 8
        }
    }

    private static func weekMultiplier(
        stage: Experience,
        weekIndex: Int,
        lower: Bool,
        compound: Bool,
        hasLog: Bool
    ) -> Double {
        guard hasLog else { return 1.0 }
        let paceLower = lower && compound
        switch stage {
        case .beginner where [2, 4].contains(weekIndex):
            return 1 + (paceLower ? 0.05 : 0.025)
        case .intermediate where weekIndex == 3:
            return 1 + (paceLower ? 0.05 : 0.025)
        case .advanced where weekIndex == 4:
            return 1 + (paceLower ? 0.025 : 0.0125)
        default:
            return 1.0
        }
    }

    private static func barbellRatio(_ exercise: Exercise) -> Double {
        let name = "\(exercise.nameZH) \(exercise.nameEN)".lowercased()
        if name.contains("硬拉") || name.contains("deadlift") { return 0.60 }
        if name.contains("深蹲") || name.contains("squat") { return 0.50 }
        if name.contains("腿举") || name.contains("leg press") { return 0.80 }
        if name.contains("卧推") || name.contains("bench") { return 0.35 }
        if name.contains("划船") || name.contains("row") { return 0.30 }
        if name.contains("推举") || name.contains("overhead") || name.contains("肩推") {
            return 0.20
        }
        return 0.30
    }

    private static func roundWeight(_ value: Double) -> Double {
        round(max(0.5, min(300, value)) * 2) / 2
    }
}
