import Foundation

/// One first-level category and its ordered second-level children.
struct ExerciseCategory: Identifiable {
    let l1: String
    let l2: [String]
    var id: String { l1 }

    init(_ l1: String, _ l2: [String]) {
        self.l1 = l1
        self.l2 = l2
    }
}

enum ExerciseLibrary {
    /// Active library shown in search, plan generation and onboarding.
    static let all: [Exercise] = load(resource: "vital_exercises")

    /// Curated "common actions" whitelist for plan generation. The user's
    /// self-selected library is unioned on top at generation time.
    static let planEligible: [Exercise] = all.filter { $0.planEligible }

    /// Two-level category tree for the library browser, in display order.
    static let categoryTree: [ExerciseCategory] = [
        ExerciseCategory("胸", ["上胸", "中下胸"]),
        ExerciseCategory("背", ["背阔肌", "大圆肌", "菱形肌", "中下斜方", "上斜方", "竖脊肌"]),
        ExerciseCategory("腿", ["股四头", "腘绳肌"]),
        ExerciseCategory("肩", ["前束", "中束", "后束"]),
        ExerciseCategory("前锯肌", []),
        ExerciseCategory("斜方肌", []),
        ExerciseCategory("手臂", ["二头", "三头"]),
        ExerciseCategory("小腿", []),
        ExerciseCategory("前臂", []),
        ExerciseCategory("臀部", ["上臀", "下臀"]),
        ExerciseCategory("功能性", ["髋", "膝关节", "肩关节"]),
        ExerciseCategory("核心", []),
        ExerciseCategory("腹部", ["腹直肌", "侧腹"]),
        ExerciseCategory("热身动作", ["胸", "上背", "下背", "腘绳肌", "大腿", "臀部", "肩膀"]),
        ExerciseCategory("拉伸", ["胸", "上背", "下背", "腘绳肌", "大腿", "臀部", "肩膀"]),
        ExerciseCategory("有氧", []),
        ExerciseCategory("全身", []),
        ExerciseCategory("other", []),
    ]

    static func subcategories(for l1: String) -> [String] {
        visibleCategoryTree.first { $0.l1 == l1 }?.l2 ?? []
    }

    /// Catch-all category stays searchable but is not a browse destination.
    private static let hiddenBrowseCategories: Set<String> = ["other"]

    /// Category tree with empty branches removed, for the library browser.
    /// Empty L1 (e.g. 前锯肌) and empty L2 (e.g. 背/大圆肌) are hidden until
    /// content exists, so users never land on a dead-end filter.
    static let visibleCategoryTree: [ExerciseCategory] = {
        var l1s = Set<String>()
        var l2ByL1: [String: Set<String>] = [:]
        for exercise in all {
            guard let l1 = exercise.categoryL1 else { continue }
            l1s.insert(l1)
            if let l2 = exercise.categoryL2 {
                l2ByL1[l1, default: []].insert(l2)
            }
        }
        return categoryTree.compactMap { entry in
            guard l1s.contains(entry.l1),
                  !hiddenBrowseCategories.contains(entry.l1) else {
                return nil
            }
            let subs = entry.l2.filter { l2ByL1[entry.l1]?.contains($0) == true }
            return ExerciseCategory(entry.l1, subs)
        }
    }()

    /// Previous curated libraries kept resolvable by slug for old plans and
    /// history, but never offered as new picks.
    private static let xunji: [Exercise] = load(resource: "xunji_movements")
    private static let legacy: [Exercise] = load(resource: "legacy_exercises")

    private static let index: [String: Exercise] = buildIndex()

    static func exercise(slug: String) -> Exercise? {
        index[slug]
    }

    static func candidates(
        muscle: MuscleGroup? = nil,
        equipment: Set<Equipment> = Set(Equipment.allCases)
    ) -> [Exercise] {
        all.filter { item in
            let muscleMatch = muscle == nil || item.muscle == muscle
            let equipmentMatch = equipment.contains(item.equipment)
            return muscleMatch && equipmentMatch
        }
    }

    static func search(_ text: String) -> [Exercise] {
        guard !text.isEmpty else { return all }
        let query = text.lowercased()
        return all.filter { $0.searchKey.contains(query) }
    }

    private static func buildIndex() -> [String: Exercise] {
        var result: [String: Exercise] = [:]
        for exercise in all {
            result[exercise.slug] = exercise
            for alias in exercise.slugAliases {
                result[alias] = exercise
            }
        }
        // Old plans/history resolve to the previous libraries if the slug is
        // no longer present in the Vital catalog.
        for exercise in xunji + legacy {
            if result[exercise.slug] == nil {
                result[exercise.slug] = exercise
            }
        }
        return result
    }

    private static func load(resource: String) -> [Exercise] {
        guard let url = resourceURL(resource),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([ResourceExercise].self, from: data) else {
            // Never trap on a missing/bad bundled resource; the app can still
            // show an empty library and remain usable.
            print("ExerciseLibrary: \(resource).json is missing or invalid")
            return []
        }
        return rows.map { row in
            Exercise(
                slug: row.slug,
                nameZH: row.nameZH,
                nameEN: row.nameEN ?? "",
                muscle: MuscleGroup(rawValue: row.muscleGroup) ?? .core,
                equipment: Equipment(rawValue: row.equipment) ?? .machine,
                isCompound: row.isCompound,
                instructions: row.instructions ?? "",
                contraindications: row.contraindications ?? [],
                motionStartURL: row.motionStartURL.flatMap { URL(string: $0) },
                motionEndURL: row.motionEndURL.flatMap { URL(string: $0) },
                thumbnailURL: AppConfig.resolveMediaURL(row.thumbnailURL),
                demoVideoURL: AppConfig.resolveMediaURL(row.videoURL),
                aliases: row.aliases ?? [],
                slugAliases: row.slugAliases ?? [],
                categoryL1: row.categoryL1,
                categoryL2: row.categoryL2,
                planEligible: row.planEligible ?? true
            )
        }
    }

    /// Hosted unit tests can report a different `Bundle.main`; the token's
    /// bundle is the app bundle that contains the JSON resources.
    private static func resourceURL(_ resource: String) -> URL? {
        let bundles = [Bundle(for: ResourceBundleToken.self), Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            if let url = bundle.url(forResource: resource, withExtension: "json") {
                return url
            }
        }
        return nil
    }
}

private final class ResourceBundleToken {}

private struct ResourceExercise: Decodable {
    let slug: String
    let nameZH: String
    let nameEN: String?
    let muscleGroup: String
    let equipment: String
    let isCompound: Bool
    let instructions: String?
    let contraindications: [String]?
    let motionStartURL: String?
    let motionEndURL: String?
    let thumbnailURL: String?
    let videoURL: String?
    let aliases: [String]?
    let slugAliases: [String]?
    let planEligible: Bool?
    let categoryL1: String?
    let categoryL2: String?

    enum CodingKeys: String, CodingKey {
        case slug
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case muscleGroup = "muscle_group"
        case equipment
        case isCompound = "is_compound"
        case instructions
        case contraindications
        case motionStartURL = "motion_start_url"
        case motionEndURL = "motion_end_url"
        case thumbnailURL = "thumbnail_url"
        case videoURL = "video_url"
        case aliases
        case slugAliases = "slug_aliases"
        case planEligible = "plan_eligible"
        case categoryL1 = "category_l1"
        case categoryL2 = "category_l2"
    }
}
