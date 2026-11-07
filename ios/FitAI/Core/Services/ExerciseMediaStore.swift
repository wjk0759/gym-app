import Foundation
import Observation

/// Fetches and caches the demo clips for the current workout day. A day has
/// only a handful of exercises, so one batch request is enough; the next
/// exercise is already warm when the user advances.
@MainActor
@Observable
final class ExerciseMediaStore {
    private(set) var itemsBySlug: [String: ExerciseMediaItem] = [:]
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var requested = Set<String>()

    func item(for slug: String) -> ExerciseMediaItem? {
        itemsBySlug[slug]
    }

    func prefetch(slugs: [String]) async {
        var seen = Set<String>()
        let unique = slugs.filter { slug in
            guard !slug.isEmpty, !seen.contains(slug) else { return false }
            seen.insert(slug)
            return true
        }
        let missing = unique.filter {
            itemsBySlug[$0] == nil && !requested.contains($0)
        }
        guard !missing.isEmpty else { return }

        requested.formUnion(missing)
        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await APIClient.shared.fetchExerciseMedia(
                slugs: missing
            )
            for item in items {
                itemsBySlug[item.exerciseSlug] = item
            }
            lastError = nil
        } catch {
            // Network failures should not keep the training screen from
            // working. Allow a later foreground pass to retry.
            requested.subtract(missing)
            lastError = (error as? APIError)?.message
                ?? "动作演示暂时不可用"
        }
    }

    func clear() {
        itemsBySlug.removeAll()
        requested.removeAll()
        lastError = nil
    }
}
