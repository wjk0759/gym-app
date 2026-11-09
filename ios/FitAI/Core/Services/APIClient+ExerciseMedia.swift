import Foundation

extension APIClient {
    /// One batch request returns all demo clips needed by the current workout.
    func fetchExerciseMedia(slugs: [String]) async throws -> [ExerciseMediaItem] {
        var seen = Set<String>()
        let unique = slugs.filter { slug in
            guard !slug.isEmpty, !seen.contains(slug) else { return false }
            seen.insert(slug)
            return true
        }
        guard !unique.isEmpty else { return [] }

        let raw = unique.prefix(20).joined(separator: ",")
        let encoded = raw.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? raw
        let response: ExerciseMediaList = try await send(
            path: "exercise-media?slugs=\(encoded)&all=true",
            method: "GET",
            body: nil,
            timeout: 30
        )
        return response.items
    }
}
