import Foundation

enum ExerciseLibrary {
    /// Active library shown in search, plan generation and onboarding.
    static let all: [Exercise] = load(resource: "xunji_movements")

    /// Existing plans/history may still reference the previous 80 exercises.
    /// Keep them resolvable by slug, but never offer them as new picks.
    private static let legacy: [Exercise] = load(resource: "legacy_exercises")

    private static let index: [String: Exercise] = Dictionary(
        uniqueKeysWithValues: (all + legacy).map { ($0.slug, $0) }
    )

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
        return all.filter {
            $0.nameZH.contains(text) || $0.nameEN.localizedCaseInsensitiveContains(text)
        }
    }

    private static func load(resource: String) -> [Exercise] {
        guard let url = resourceURL(resource),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([ResourceExercise].self, from: data) else {
            assertionFailure("\(resource).json is missing or invalid")
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
                motionEndURL: row.motionEndURL.flatMap { URL(string: $0) }
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
    }
}
