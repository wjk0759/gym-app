import Foundation

struct ExerciseSubstitution: Identifiable, Hashable {
    let exercise: Exercise
    let reason: String
    let lastSet: SetLog?
    let isOutsideLibrary: Bool
    let isBodyweightFallback: Bool

    var id: String { exercise.slug }
}

enum ExerciseSubstitutionSource: Equatable {
    case personal
    case bodyweight
    case empty
}

struct ExerciseSubstitutionResult {
    let source: ExerciseSubstitutionSource
    let items: [ExerciseSubstitution]
}

/// Picks 3–9 in-workout replacements without calling the AI.
///
/// Personal equipment is the primary pool: fixed machines use the curated
/// equipment catalog, universal equipment uses the exercise library. When the
/// strict setting produces no candidates, a small hand-picked bodyweight list
/// is used as the last resort.
enum ExerciseSubstitutionEngine {
    static func candidates(
        for current: Exercise,
        equipmentLibrary: [EquipmentItem],
        universalSlugs: [String],
        profile: UserProfile,
        strictEquipment: Bool,
        todaySlugs: Set<String>,
        lastSet: @escaping (String) -> SetLog?,
        limit: Int = 9
    ) -> ExerciseSubstitutionResult {
        let context = Context(
            current: current,
            equipmentLibrary: equipmentLibrary,
            universalSlugs: Set(universalSlugs),
            profile: profile,
            todaySlugs: todaySlugs,
            lastSet: lastSet
        )

        var items = personalCandidates(context)
        if !strictEquipment, items.count < 3 {
            items.append(contentsOf: outsideCandidates(context))
        }
        items = dedupe(items)

        if !items.isEmpty {
            return ExerciseSubstitutionResult(
                source: .personal,
                items: Array(items.prefix(limit))
            )
        }

        let bodyweight = bodyweightCandidates(context)
        if !bodyweight.isEmpty {
            return ExerciseSubstitutionResult(
                source: .bodyweight,
                items: Array(bodyweight.prefix(limit))
            )
        }

        return ExerciseSubstitutionResult(source: .empty, items: [])
    }

    static func pickerExercises(
        for current: Exercise,
        equipmentLibrary: [EquipmentItem],
        universalSlugs: [String],
        profile: UserProfile,
        strictEquipment: Bool,
        todaySlugs: Set<String>,
        lastSet: @escaping (String) -> SetLog?
    ) -> [Exercise] {
        let context = Context(
            current: current,
            equipmentLibrary: equipmentLibrary,
            universalSlugs: Set(universalSlugs),
            profile: profile,
            todaySlugs: todaySlugs,
            lastSet: lastSet
        )

        var items = personalCandidates(context).map(\.exercise)
        if !strictEquipment {
            items.append(contentsOf: outsideCandidates(context).map(\.exercise))
        }
        items.append(contentsOf: bodyweightCandidates(context).map(\.exercise))

        var seen = Set<String>()
        return items
            .filter { seen.insert($0.slug).inserted }
            .sorted { $0.nameZH < $1.nameZH }
    }

    // MARK: - Candidate pools

    private static func personalCandidates(_ context: Context) -> [ExerciseSubstitution] {
        var pool: [Exercise] = []
        var curated = Set<String>()
        var seen = Set<String>()

        func add(_ exercise: Exercise, curatedFlag: Bool = false) {
            guard seen.insert(exercise.slug).inserted else { return }
            if curatedFlag {
                curated.insert(exercise.slug)
            }
            pool.append(exercise)
        }

        // The occupied machine's curated alternatives are the highest-signal
        // source: they already know which movements replace this pattern.
        for typeSlug in context.current.equipmentTypes {
            if let info = EquipmentCatalog.type(for: typeSlug) {
                info.similarExercises.forEach { add($0, curatedFlag: true) }
            }
            for info in EquipmentCatalog.all where info.exerciseGroup == typeSlug {
                info.similarExercises.forEach { add($0, curatedFlag: true) }
            }
        }

        // Every other machine in the personal library contributes its own
        // curated actions.
        for item in context.equipmentLibrary {
            guard let info = EquipmentCatalog.type(for: item.equipmentType) else { continue }
            info.trainableExercises.forEach { add($0) }
        }

        // Universal equipment (dumbbell, barbell, band...) comes from the big
        // library, but still has to pass the personal-equipment check.
        for slug in context.universalSlugs where slug != "bodyweight" {
            for exercise in ExerciseLibrary.universalExercises[slug] ?? [] {
                add(exercise)
            }
        }

        let filtered = pool.filter { context.isEligiblePersonalCandidate($0) }
        return ranked(
            filtered,
            current: context.current,
            context: context,
            curated: curated,
            outside: false
        )
    }

    private static func outsideCandidates(_ context: Context) -> [ExerciseSubstitution] {
        let pool = ExerciseLibrary.planEligible.filter { exercise in
            exercise.slug != context.current.slug
                && exercise.equipment != .bodyweight
                && exercise.muscle == context.current.muscle
                && (
                    exercise.categoryL2 == nil
                        || context.current.categoryL2 == nil
                        || exercise.categoryL2 == context.current.categoryL2
                )
                && !context.todaySlugs.contains(exercise.slug)
                && context.profile.equipment.contains(exercise.equipment)
                && context.isInjurySafe(exercise)
        }
        return Array(
            ranked(
                pool,
                current: context.current,
                context: context,
                curated: [],
                outside: true
            ).prefix(6)
        )
    }

    private static func bodyweightCandidates(_ context: Context) -> [ExerciseSubstitution] {
        var pool: [Exercise] = []
        var seen = Set<String>()

        func add(_ slug: String) {
            guard let exercise = ExerciseLibrary.exercise(slug: slug),
                  seen.insert(exercise.slug).inserted,
                  exercise.slug != context.current.slug,
                  exercise.planEligible,
                  exercise.equipment == .bodyweight,
                  !context.todaySlugs.contains(exercise.slug),
                  context.isInjurySafe(exercise),
                  !isAdvancedBodyweight(exercise) else {
                return
            }
            pool.append(exercise)
        }

        let curated = bodyweightFallbackSlugs(for: context.current)
        curated.forEach { add($0) }

        if pool.count < 3, !curated.isEmpty {
            for exercise in ExerciseLibrary.planEligible
            where exercise.equipment == .bodyweight
                && exercise.muscle == context.current.muscle
                && !seen.contains(exercise.slug) {
                add(exercise.slug)
            }
        }

        return rankedBodyweight(pool, current: context.current, context: context)
    }

    // MARK: - Ranking

    private static func ranked(
        _ exercises: [Exercise],
        current: Exercise,
        context: Context,
        curated: Set<String>,
        outside: Bool
    ) -> [ExerciseSubstitution] {
        exercises
            .map { exercise -> (Exercise, Int) in
                var score = 0
                if let pattern = exercise.movementPattern,
                   pattern == current.movementPattern {
                    score += 100
                }
                if exercise.muscle == current.muscle {
                    score += 40
                }
                if let l2 = exercise.categoryL2,
                   l2 == current.categoryL2 {
                    score += 30
                }
                if exercise.isCompound == current.isCompound {
                    score += 15
                }
                if curated.contains(exercise.slug) {
                    score += 20
                }
                if context.lastSet(exercise.slug) != nil {
                    score += 10
                }
                if outside {
                    score -= 10
                }
                return (exercise, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.nameZH < rhs.0.nameZH
            }
            .map { pair in
                ExerciseSubstitution(
                    exercise: pair.0,
                    reason: reason(
                        for: pair.0,
                        current: current,
                        bodyweight: false,
                        outside: outside
                    ),
                    lastSet: context.lastSet(pair.0.slug),
                    isOutsideLibrary: outside,
                    isBodyweightFallback: false
                )
            }
    }

    private static func rankedBodyweight(
        _ exercises: [Exercise],
        current: Exercise,
        context: Context
    ) -> [ExerciseSubstitution] {
        exercises
            .map { exercise -> (Exercise, Int) in
                var score = 0
                if let pattern = exercise.movementPattern,
                   pattern == current.movementPattern {
                    score += 80
                }
                if exercise.muscle == current.muscle {
                    score += 40
                }
                if context.profile.trainingStage == .beginner {
                    if beginnerFriendlyKeywords.contains(
                        where: { exercise.nameZH.contains($0) }
                    ) {
                        score += 20
                    }
                } else if ["标准", "单腿", "派克"].contains(
                    where: { exercise.nameZH.contains($0) }
                ) {
                    score += 10
                }
                if context.lastSet(exercise.slug) != nil {
                    score += 10
                }
                return (exercise, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                return lhs.0.nameZH < rhs.0.nameZH
            }
            .map { pair in
                ExerciseSubstitution(
                    exercise: pair.0,
                    reason: "不需要器械，原地就能做",
                    lastSet: context.lastSet(pair.0.slug),
                    isOutsideLibrary: false,
                    isBodyweightFallback: true
                )
            }
    }

    private static func dedupe(_ items: [ExerciseSubstitution]) -> [ExerciseSubstitution] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.exercise.slug).inserted }
    }

    private static func reason(
        for exercise: Exercise,
        current: Exercise,
        bodyweight: Bool,
        outside: Bool
    ) -> String {
        if bodyweight {
            return "不需要器械，原地就能做"
        }
        if outside {
            return "不在你的器械库，馆里可能有"
        }
        if let pattern = exercise.movementPattern,
           pattern == current.movementPattern {
            return "同是\(pattern)的动作，练\(exercise.muscle.label)"
        }
        if exercise.muscle == current.muscle {
            return "同是练\(exercise.muscle.label)"
        }
        return "器械不同，刺激接近"
    }

    // MARK: - Bodyweight fallback

    private static let beginnerFriendlyKeywords = ["上斜", "靠墙", "臀桥", "死虫", "跪姿"]

    private static func bodyweightFallbackSlugs(for current: Exercise) -> [String] {
        switch current.muscle {
        case .chest:
            return [
                "vital-incline-push-up",
                "vital-standard-push-up",
                "vital-close-grip-push-ups"
            ]
        case .back:
            return [
                "vital-y-t-w-beginners",
                "vital-modified-superman-hold-legs-grounded"
            ]
        case .shoulders:
            return ["vital-pike-push-up"]
        case .arms:
            // There is no zero-equipment biceps movement in the library;
            // triceps can use a diamond push-up.
            if current.categoryL2 == "二头" {
                return []
            }
            return ["vital-diamond-push-up"]
        case .legs:
            if current.categoryL2 == "小腿" {
                return ["vital-standing-calf-raise", "vital-calf-raise"]
            }
            if current.movementPattern == "弓步" {
                return ["vital-forward-lunges", "vital-reverse-lunges"]
            }
            if current.movementPattern == "髋铰链" || current.movementPattern == "拉" {
                return [
                    "vital-glute-bridge",
                    "vital-single-leg-glute-bridge",
                    "vital-bodyweight-roman-deadlift"
                ]
            }
            return [
                "vital-wall-sit",
                "vital-air-squat",
                "vital-sumo-squat"
            ]
        case .glutes:
            return [
                "vital-glute-bridge",
                "vital-single-leg-glute-bridge"
            ]
        case .core:
            return [
                "vital-standard-plank",
                "vital-dead-bug",
                "vital-lying-leg-raise"
            ]
        case .cardio:
            return []
        }
    }

    private static func isAdvancedBodyweight(_ exercise: Exercise) -> Bool {
        let banned = [
            "负重", "跳", "波比", "手枪", "倒立",
            "单臂", "单手", "击掌", "爆发", "龙旗", "健腹轮"
        ]
        return banned.contains { exercise.nameZH.contains($0) }
    }

    // MARK: - Availability

    private struct Context {
        let current: Exercise
        let equipmentLibrary: [EquipmentItem]
        let universalSlugs: Set<String>
        let profile: UserProfile
        let todaySlugs: Set<String>
        let lastSet: (String) -> SetLog?
        let injuryTags: Set<String>
        let availableSlugs: Set<String>

        init(
            current: Exercise,
            equipmentLibrary: [EquipmentItem],
            universalSlugs: Set<String>,
            profile: UserProfile,
            todaySlugs: Set<String>,
            lastSet: @escaping (String) -> SetLog?
        ) {
            self.current = current
            self.equipmentLibrary = equipmentLibrary
            self.universalSlugs = universalSlugs
            self.profile = profile
            self.todaySlugs = todaySlugs
            self.lastSet = lastSet
            self.injuryTags = PlanGenerator.injuryTags(profile.injuries)

            var slugs = universalSlugs
            for item in equipmentLibrary {
                guard let type = item.equipmentType else { continue }
                slugs.insert(type)
                if let group = EquipmentCatalog.group(for: type) {
                    slugs.insert(group)
                }
            }
            self.availableSlugs = slugs
        }

        func isInjurySafe(_ exercise: Exercise) -> Bool {
            guard injuryTags.isDisjoint(with: Set(exercise.contraindications)) else {
                return false
            }
            let name = exercise.nameZH
            if injuryTags.contains("knee_pain"),
               ["跳", "波比", "深蹲", "弓步"].contains(where: { name.contains($0) }) {
                return false
            }
            if injuryTags.contains("lower_back"),
               ["硬拉", "俯身", "早安", "山羊挺身"].contains(where: { name.contains($0) }) {
                return false
            }
            if injuryTags.contains("shoulder_pain"),
               ["推举", "肩推", "直立划船", "双杠臂屈伸", "倒立"].contains(
                   where: { name.contains($0) }
               ) {
                return false
            }
            if injuryTags.contains("wrist_pain"),
               ["俯卧撑", "平板", "前蹲"].contains(where: { name.contains($0) }) {
                return false
            }
            if injuryTags.contains("elbow_pain"),
               ["弯举", "下压", "臂屈伸"].contains(where: { name.contains($0) }) {
                return false
            }
            if injuryTags.contains("ankle_pain"),
               ["跳", "提踵"].contains(where: { name.contains($0) }) {
                return false
            }
            return true
        }

        func isAvailable(_ exercise: Exercise) -> Bool {
            if exercise.equipment == .bodyweight {
                return true
            }

            let exerciseTypes = Set(exercise.equipmentTypes)
            if exercise.nameZH.contains("球"),
               !universalSlugs.contains("medicine_ball") {
                return false
            }
            if exercise.nameZH.contains("滑盘") {
                return false
            }
            let knownTypes = Set(EquipmentCatalog.all.map(\.slug))
            let knownGroups = Set(EquipmentCatalog.all.map(\.exerciseGroup))
            let required = exerciseTypes.filter {
                knownTypes.contains($0) || knownGroups.contains($0)
            }
            guard required.allSatisfy({ slug in
                availableSlugs.contains(slug)
                    || (slug == "squat_rack" && availableSlugs.contains("bench_press"))
                    || (slug == "bench_press" && availableSlugs.contains("squat_rack"))
            }) else {
                return false
            }

            let loadSlugs: Set<String> = ["dumbbell", "barbell", "kettlebell", "band"]
            let loads = exerciseTypes.intersection(loadSlugs)
            if !loads.isEmpty {
                let hasLoad = loads.contains {
                    universalSlugs.contains($0)
                        || profile.equipment.contains(exercise.equipment)
                }
                guard hasLoad else { return false }
            }

            if required.isEmpty && loads.isEmpty {
                return profile.equipment.contains(exercise.equipment)
                    || !exerciseTypes.isDisjoint(with: universalSlugs)
            }
            return true
        }

        func isEligiblePersonalCandidate(_ exercise: Exercise) -> Bool {
            exercise.slug != current.slug
                && exercise.equipment != .bodyweight
                && exercise.muscle == current.muscle
                && (
                    exercise.categoryL2 == nil
                        || current.categoryL2 == nil
                        || exercise.categoryL2 == current.categoryL2
                )
                && exercise.planEligible
                && !todaySlugs.contains(exercise.slug)
                && isInjurySafe(exercise)
                && isAvailable(exercise)
        }
    }
}
