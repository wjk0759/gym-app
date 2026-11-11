import Foundation

/// 70 类物理器械目录（来自无水印图片集）。
struct EquipmentTypeInfo: Decodable, Identifiable {
    let slug: String
    let nameZH: String
    let nameEN: String?
    let category: String
    let bodyPart: String?
    let secondaryBodyParts: [String]?
    let targetMuscles: [String]?
    let exerciseGroup: String
    let exerciseSlugs: [String]?
    let imageURLs: [String]?
    let universal: Bool
    let aliases: [String]?

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case category
        case bodyPart = "body_part"
        case secondaryBodyParts = "secondary_body_parts"
        case targetMuscles = "target_muscles"
        case exerciseGroup = "exercise_group"
        case exerciseSlugs = "exercise_slugs"
        case imageURLs = "image_urls"
        case universal
        case aliases
    }

    var bodyPartLabel: String {
        bodyPart ?? "全身"
    }

    var secondaryBodyPartList: [String] {
        secondaryBodyParts ?? []
    }

    var targetMuscleList: [String] {
        targetMuscles ?? []
    }

    var imageURLList: [String] {
        imageURLs ?? []
    }

    var categoryLabel: String {
        switch category {
        case "machine": return "固定器械"
        case "cable": return "绳索器械"
        case "multi": return "综合器械"
        case "free_weight": return "自由重量"
        case "cardio": return "有氧器械"
        case "bodyweight": return "自重"
        case "accessory": return "小工具"
        default: return "器械"
        }
    }

    var symbolName: String {
        switch category {
        case "cardio": return "figure.run"
        case "free_weight": return "dumbbell"
        case "cable": return "point.3.connected.trianglepath.dotted"
        case "accessory": return "link"
        case "bodyweight": return "figure.strengthtraining.functional"
        default: return "gearshape.fill"
        }
    }

    var targetSummary: String {
        let muscles = targetMuscleList
        guard !muscles.isEmpty else { return "训练部位待补充" }
        let preview = muscles.prefix(2).joined(separator: "、")
        return muscles.count > 2 ? "\(preview) 等" : preview
    }

    /// 优先使用目录里显式给出的动作；否则按动作库的 equipment_group 过滤。
    var trainableExercises: [Exercise] {
        if let exerciseSlugs, !exerciseSlugs.isEmpty {
            let rows = exerciseSlugs.compactMap { ExerciseLibrary.exercise(slug: $0) }
            if !rows.isEmpty {
                return rows.sorted { $0.nameZH < $1.nameZH }
            }
        }
        return ExerciseLibrary.all
            .filter { $0.equipmentTypes.contains(exerciseGroup) }
            .sorted { $0.nameZH < $1.nameZH }
    }

    var planEligibleExercises: [Exercise] {
        trainableExercises.filter(\.planEligible)
    }
}

enum EquipmentCatalog {
    static let all: [EquipmentTypeInfo] = load()

    /// 添加页左侧部位栏。顺序与动作库一致。
    static let bodyParts: [String] = [
        "胸", "背", "肩", "臂", "腿", "臀", "核心", "有氧", "全身"
    ]

    private static func load() -> [EquipmentTypeInfo] {
        let bundles = [Bundle(for: EquipmentBundleToken.self), Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            guard let url = bundle.url(forResource: "equipment_catalog", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let rows = try? JSONDecoder().decode([EquipmentTypeInfo].self, from: data)
            else {
                continue
            }
            return rows
        }
        return []
    }

    static func type(for slug: String?) -> EquipmentTypeInfo? {
        guard let slug else { return nil }
        return all.first { $0.slug == slug }
    }

    static func group(for typeSlug: String?) -> String? {
        type(for: typeSlug)?.exerciseGroup
    }

    static func types(for bodyPart: String?) -> [EquipmentTypeInfo] {
        guard let bodyPart, !bodyPart.isEmpty else { return all }
        return all.filter { $0.bodyPartLabel == bodyPart }
    }

    static func count(for bodyPart: String) -> Int {
        all.filter { $0.bodyPartLabel == bodyPart }.count
    }
}

private final class EquipmentBundleToken {}
