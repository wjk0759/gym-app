import Foundation

struct ExerciseVideoService {
    var client: APIClient = .shared

    func officialURL(slug: String) async throws -> URL? {
        try await client.officialVideoURL(slug: slug)
    }
}
