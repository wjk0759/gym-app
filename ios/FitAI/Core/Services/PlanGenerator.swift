import Foundation

enum PlanGenerator {
    private struct GoalParams {
        let sets: Int
        let reps: String
        let rest: Int
        let rpe: Double
    }

    private static let goalParams: [GoalType: GoalParams] = [
        .loseFat: GoalParams(sets: 3, reps: "12-15", rest: 45, rpe: 7.0),
        .buildMuscle: GoalParams(sets: 4, reps: "8-10", rest: 90, rpe: 7.5),
        .recomp: GoalParams(sets: 3, reps: "10-12", rest: 60, rpe: 7.0),
        .endurance: GoalParams(sets: 3, reps: "15-20", rest: 30, rpe: 6.5)
    ]

    private static let defaultWeekdays: [Int: [Int]] = [
        1: [3],
        2: [2, 5],
        3: [1, 3, 5],
        4: [1, 2, 4, 5],
        5: [1, 2, 3, 5, 6],
        6: [1, 2, 3, 4, 5, 6],
        7: [1, 2, 3, 4, 5, 6, 7]
    ]

    private static let fullBody: [MuscleGroup] = [.legs, .chest, .back, .shoulders, .core]
    private static let upper: [MuscleGroup] = [.chest, .back, .shoulders, .arms, .arms]
    private static let lower: [MuscleGroup] = [.legs, .glutes, .legs, .core, .core]
    private static let push: [MuscleGroup] = [.chest, .chest, .shoulders, .shoulders, .arms]
    private static let pull: [MuscleGroup] = [.back, .back, .back, .arms, .core]
    private static let legDay: [MuscleGroup] = [.legs, .legs, .glutes, .legs, .core]

    private static let splits: [Int: [(String, [MuscleGroup])]] = [
        1: [("全身训练", fullBody)],
        2: [("全身 A", fullBody), ("全身 B", [.legs, .back, .chest, .core])],
        3: [
            ("全身 A", [.legs, .chest, .back, .core]),
            ("全身 B", [.legs, .shoulders, .back, .core]),
            ("全身 C", [.glutes, .chest, .arms, .core])
        ],
        4: [
            ("上肢 A", upper),
            ("下肢 A", lower),
            ("上肢 B", [.back, .chest, .shoulders, .arms, .arms]),
            ("下肢 B", [.glutes, .legs, .legs, .core, .core])
        ],
        5: [
            ("推 · 胸肩三头", push),
            ("拉 · 背二头", pull),
            ("腿 · 下肢", legDay),
            ("上肢综合", upper),
            ("下肢综合", lower)
        ],
        6: [
            ("推 A", push),
            ("拉 A", pull),
            ("腿 A", legDay),
            ("推 B", [.shoulders, .chest, .chest, .arms, .arms]),
            ("拉 B", [.back, .back, .arms, .arms, .core]),
            ("腿 B", [.glutes, .legs, .legs, .core, .core])
        ],
        7: [
            ("推", push),
            ("拉", pull),
            ("腿", legDay),
            ("上肢", upper),
            ("下肢", lower),
            ("全身", fullBody),
            ("恢复与核心", [.core, .cardio, .core, .glutes])
        ]
    ]

    static func generate(profile: UserProfile) -> TrainingPlan {
        let available = allowedExercises(profile)
        let weeklyDays = max(1, min(7, profile.weeklyDays))
        let weekdays = defaultWeekdays[weeklyDays] ?? Array(1...weeklyDays)
        let split = splits[weeklyDays] ?? splits[3]!
        let count = exerciseCount(minutes: profile.sessionMinutes)
        let params = goalParams[profile.goalType] ?? goalParams[.recomp]!
        let weeks = 4

        var days: [PlanDay] = []
        for week in 1...weeks {
            for (index, weekday) in weekdays.enumerated() {
                let (title, focus) = split[index % split.count]
                let picks = pickExercises(focus: focus, from: available, count: count)
                guard !picks.isEmpty else { continue }

                let exercises = picks.enumerated().map { offset, exercise -> PlanExercise in
                    var weight = suggestedWeight(exercise, experience: profile.experience)
                    if let base = weight, week > 1 {
                        weight = ((base * (1 + 0.025 * Double(week - 1))) * 2).rounded() / 2
                    }
                    return PlanExercise(
                        slug: exercise.slug,
                        sets: params.sets,
                        reps: reps(for: exercise, goal: profile.goalType),
                        weightKG: weight,
                        restSec: params.rest,
                        rpe: params.rpe
                    )
                }

                days.append(
                    PlanDay(
                        weekIndex: week,
                        weekday: weekday,
                        title: title,
                        focus: focus,
                        exercises: exercises
                    )
                )
            }
        }

        let goalLabel = profile.goalType.label
        return TrainingPlan(
            title: "4 周\(goalLabel)计划 · 每周 \(weeklyDays) 练",
            weeks: weeks,
            days: days
        )
    }

    static func adjusted(
        plan: TrainingPlan,
        profile: UserProfile,
        completionRate: Double
    ) -> (plan: TrainingPlan, message: String) {
        var newPlan = plan
        newPlan.id = UUID()
        newPlan.version = plan.version + 1
        newPlan.createdAt = Date()
        newPlan.title = plan.title + " · 调整版"

        newPlan.days = plan.days.map { day in
            var newDay = day
            newDay.id = UUID()
            newDay.exercises = day.exercises.map { item in
                var newItem = item
                newItem.id = UUID()
                if completionRate < 0.6 {
                    newItem.sets = max(2, item.sets - 1)
                } else if completionRate >= 0.8, let weight = item.weightKG, weight > 0 {
                    newItem.weightKG = ((weight * 1.025) * 2).rounded() / 2
                }
                return newItem
            }
            return newDay
        }

        let message: String
        if completionRate < 0.6 {
            message = "最近完成率 \(Int(completionRate * 100))%，每个动作减少 1 组，先把规律建立起来。"
        } else if completionRate >= 0.8 {
            message = "最近完成率 \(Int(completionRate * 100))%，主项重量上调 2.5%。"
        } else {
            message = "最近完成率 \(Int(completionRate * 100))%，本周保持负荷，优先补齐训练日。"
        }
        return (newPlan, message)
    }

    // MARK: - 内部规则

    private static func exerciseCount(minutes: Int) -> Int {
        switch minutes {
        case ..<31: return 4
        case 31...45: return 5
        default: return 6
        }
    }

    private static func reps(for exercise: Exercise, goal: GoalType) -> String {
        if exercise.slug == "plank" { return "30-45s" }
        if exercise.slug == "rowing_machine" || exercise.slug == "treadmill_walk" {
            return "8-12 min"
        }
        return goalParams[goal]?.reps ?? "10-12"
    }

    private static func suggestedWeight(
        _ exercise: Exercise,
        experience: Experience
    ) -> Double? {
        if exercise.equipment == .bodyweight { return nil }
        let base: Double
        switch exercise.equipment {
        case .dumbbell: base = 8
        case .barbell: base = 20
        case .machine: base = 15
        case .cable: base = 10
        case .band: base = 5
        case .kettlebell: base = 8
        case .bodyweight: base = 0
        }
        let multiplier: Double
        switch experience {
        case .beginner: multiplier = 1.0
        case .intermediate: multiplier = 1.5
        case .advanced: multiplier = 2.0
        }
        let compoundFactor = exercise.isCompound ? 1.0 : 0.6
        return ((base * multiplier * compoundFactor) * 2).rounded() / 2
    }

    private static func allowedExercises(_ profile: UserProfile) -> [Exercise] {
        let banned = injuryTags(profile.injuries)
        let equipment = profile.availableEquipment
        let filtered = ExerciseLibrary.all.filter { exercise in
            let equipmentOK = equipment.contains(exercise.equipment)
            let injuryOK = banned.isDisjoint(with: Set(exercise.contraindications))
            return equipmentOK && injuryOK
        }
        return filtered.isEmpty ? ExerciseLibrary.all : filtered
    }

    private static func injuryTags(_ text: String) -> Set<String> {
        let mapping: [(String, String)] = [
            ("膝", "knee_pain"),
            ("半月板", "knee_pain"),
            ("腰", "lower_back"),
            ("腰椎", "lower_back"),
            ("肩", "shoulder_pain"),
            ("肩袖", "shoulder_pain"),
            ("腕", "wrist_pain"),
            ("手腕", "wrist_pain"),
            ("踝", "ankle_pain"),
            ("脚踝", "ankle_pain"),
            ("肘", "elbow_pain"),
            ("网球肘", "elbow_pain")
        ]
        var tags = Set<String>()
        for (keyword, tag) in mapping where text.contains(keyword) {
            tags.insert(tag)
        }
        return tags
    }

    private static func pickExercises(
        focus: [MuscleGroup],
        from available: [Exercise],
        count: Int
    ) -> [Exercise] {
        var picks: [Exercise] = []
        var used = Set<String>()

        for muscle in focus where picks.count < count {
            let candidates = available
                .filter { $0.muscle == muscle && !used.contains($0.slug) }
                .sorted { lhs, rhs in
                    if lhs.isCompound != rhs.isCompound { return lhs.isCompound }
                    return lhs.equipment.rawValue < rhs.equipment.rawValue
                }
            if let first = candidates.first {
                picks.append(first)
                used.insert(first.slug)
            }
        }

        if picks.count < count {
            let allowCardio = focus.contains(.cardio)
            let rest = available
                .filter { !used.contains($0.slug) }
                .filter { allowCardio || $0.muscle != .cardio }
                .sorted { lhs, rhs in
                    if lhs.isCompound != rhs.isCompound { return lhs.isCompound }
                    return lhs.equipment.rawValue < rhs.equipment.rawValue
                }
            for exercise in rest where picks.count < count {
                picks.append(exercise)
                used.insert(exercise.slug)
            }
        }

        return Array(picks.prefix(count))
    }
}
