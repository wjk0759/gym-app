import Foundation

/// 动作官方视频查询边界；只读 API，不缓存或写用户数据。
struct ExerciseVideoService {
    var client: APIClient = .shared

    func officialURL(slug: String) async throws -> URL? {
        try await client.officialVideoURL(slug: slug)
    }
}
