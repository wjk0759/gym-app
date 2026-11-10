import Foundation

/// 94 类器械目录（iOS 打包版，含 class -> exercise_group 映射）。
struct EquipmentTypeInfo: Decodable, Identifiable {
    let slug: String
    let nameZH: String
    let nameEN: String?
    let category: String
    let muscleCategory: String?
    let exerciseGroup: String
    let universal: Bool
    let aliases: [String]?

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case nameZH = "name_zh"
        case nameEN = "name_en"
        case category
        case muscleCategory = "muscle_category"
        case exerciseGroup = "exercise_group"
        case universal
        case aliases
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
}

enum EquipmentCatalog {
    static let all: [EquipmentTypeInfo] = load()

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

    static var universal: [EquipmentTypeInfo] {
        all.filter(\.universal)
    }

    /// 器械库浏览页的一级分类。
    static let browseCategories: [String] = [
        "固定器械", "自由重量", "有氧器械", "自重", "小工具"
    ]

    static func browseCategory(of info: EquipmentTypeInfo) -> String {
        switch info.category {
        case "machine", "cable", "multi": return "固定器械"
        case "free_weight": return "自由重量"
        case "cardio": return "有氧器械"
        case "bodyweight": return "自重"
        default: return "小工具"
        }
    }
}

private final class EquipmentBundleToken {}
