import Foundation

/// 器械使用指南静态目录（设置/步骤/提示），只读资源。
struct EquipmentGuide: Decodable {
    let setup: String
    let steps: [String]
    let cues: [String: String]
    let safety: [String]
}

enum EquipmentGuideCatalog {
    static let all: [String: EquipmentGuide] = load()

    static func guide(for slug: String?) -> EquipmentGuide? {
        guard let slug else { return nil }
        return all[slug]
    }

    private static func load() -> [String: EquipmentGuide] {
        let bundles = [Bundle(for: EquipmentGuideBundleToken.self), Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            guard let url = bundle.url(forResource: "equipment_guides", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let rows = try? JSONDecoder().decode([String: EquipmentGuide].self, from: data)
            else {
                continue
            }
            return rows
        }
        return [:]
    }
}

private final class EquipmentGuideBundleToken {}
