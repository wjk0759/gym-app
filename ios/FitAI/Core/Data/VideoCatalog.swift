import Foundation

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
