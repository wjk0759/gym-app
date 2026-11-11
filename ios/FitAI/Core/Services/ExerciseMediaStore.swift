import Foundation
import Observation

/// Fetches and caches the demo clips for the current workout day. A day has
/// only a handful of exercises, so one batch request is enough; the next
/// exercise is already warm when the user advances.
@MainActor
@Observable
final class ExerciseMediaStore {
    private(set) var itemsBySlug: [String: [ExerciseMediaItem]] = [:]
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var requested = Set<String>()

    /// Primary (first) variant for the workout loop.
    func item(for slug: String) -> ExerciseMediaItem? {
        itemsBySlug[slug]?.first
    }

    /// All variants, already ordered primary-first by the resolver.
    func items(for slug: String) -> [ExerciseMediaItem] {
        itemsBySlug[slug] ?? []
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

        // The local v2 catalog already carries every clip. Install it first so
        // the workout card never waits on a network round trip; the API pass
        // below can still replace it with a sex-matched variant.
        installLocalFallbacks(for: missing)

        do {
            let items = try await APIClient.shared.fetchExerciseMedia(
                slugs: missing
            )
            for item in items {
                itemsBySlug[item.exerciseSlug, default: []].append(item)
            }
            for (slug, variants) in itemsBySlug {
                itemsBySlug[slug] = variants.sorted { lhs, rhs in
                    if lhs.isPrimaryForWatch != rhs.isPrimaryForWatch {
                        return lhs.isPrimaryForWatch
                    }
                    return (lhs.visualPriority ?? 99) < (rhs.visualPriority ?? 99)
                }
            }
            installLocalFallbacks(for: missing)
            lastError = nil
        } catch {
            // Network failures should not keep the training screen from
            // working. Allow a later foreground pass to retry.
            requested.subtract(missing)
            installLocalFallbacks(for: missing)
            lastError = (error as? APIError)?.message
                ?? "动作演示暂时不可用"
        }
    }

    /// Fills missing slugs from the bundled v2 catalog. This is a safety net
    /// for old media records, sex fallbacks and short network outages.
    private func installLocalFallbacks(for slugs: [String]) {
        for slug in slugs {
            guard itemsBySlug[slug]?.isEmpty ?? true,
                  let exercise = ExerciseLibrary.exercise(slug: slug)
            else { continue }

            let variants = exercise.mediaVariants.enumerated().compactMap {
                index, variant in
                guard variant.videoURL != nil || variant.posterURL != nil
                else { return nil }
                return ExerciseMediaItem(
                    exerciseSlug: slug,
                    localVariant: variant,
                    index: index
                )
            }
            if !variants.isEmpty {
                itemsBySlug[slug] = variants
            }
        }
    }

    func clear() {
        itemsBySlug.removeAll()
        requested.removeAll()
        lastError = nil
    }
}
