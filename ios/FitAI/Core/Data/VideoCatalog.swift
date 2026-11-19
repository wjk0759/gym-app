import Foundation

/// 本地视频目录映射（动作 slug -> 视频 URL），只读资源。
enum VideoCatalog {
    private static let mapping: [String: URL] = {
        guard let url = Bundle.main.url(forResource: "videos", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return raw.compactMapValues { URL(string: $0) }
    }()

    static func url(for slug: String) -> URL? {
        mapping[slug]
    }
}
