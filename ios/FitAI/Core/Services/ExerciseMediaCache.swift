import Foundation

/// On-disk cache for phone demo videos and posters.
///
/// The exercise media service returns remote URLs; without a local cache every
/// re-open re-downloads the same clip. This cache stores the phone MP4 (and the
/// poster) under Caches/ExerciseMedia so repeat views hit disk, not the CDN.
/// Files are re-downloadable, so the system may purge them under storage
/// pressure without losing data.
@MainActor
final class ExerciseMediaCache {
    static let shared = ExerciseMediaCache()

    /// Soft cap. Older files are evicted first when the directory grows past it.
    private let maxBytes: Int64 = 256 * 1024 * 1024

    private let fileManager = FileManager.default

    private init() {
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func cachedVideoURL(for media: ExerciseMediaItem) -> URL? {
        localURL(for: media, kind: "video")
    }

    func cachedPosterURL(for media: ExerciseMediaItem) -> URL? {
        localURL(for: media, kind: "poster")
    }

    /// Returns the local video URL, downloading the phone clip first if needed.
    /// Falls back to `nil` (caller uses the remote URL) on failure.
    func ensureVideoCached(_ media: ExerciseMediaItem) async -> URL? {
        if let cached = cachedVideoURL(for: media) {
            return cached
        }
        guard let remote = media.phoneURL else { return nil }
        return await download(remote, for: media, kind: "video")
    }

    /// Returns the local poster URL, downloading it first if needed.
    func ensurePosterCached(_ media: ExerciseMediaItem) async -> URL? {
        if let cached = cachedPosterURL(for: media) {
            return cached
        }
        guard let remote = media.posterURL else { return nil }
        return await download(remote, for: media, kind: "poster")
    }

    private func localURL(for media: ExerciseMediaItem, kind: String) -> URL? {
        let url = fileURL(for: media, kind: kind)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func download(
        _ remote: URL,
        for media: ExerciseMediaItem,
        kind: String
    ) async -> URL? {
        do {
            let (temporary, _) = try await URLSession.shared.download(from: remote)
            let destination = fileURL(for: media, kind: kind)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporary, to: destination)
            pruneIfNeeded()
            return destination
        } catch {
            return nil
        }
    }

    private func fileURL(for media: ExerciseMediaItem, kind: String) -> URL {
        let remote = kind == "poster" ? media.posterURL : media.phoneURL
        let mediaFolder = remote?
            .deletingLastPathComponent()
            .lastPathComponent ?? "v\(media.version)"
        let cacheKey = "\(media.id)-\(mediaFolder)"
        let safe = cacheKey.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let ext: String
        if kind == "poster" {
            let pathExt = media.posterURL?.pathExtension ?? ""
            ext = pathExt.isEmpty ? "jpg" : pathExt
        } else {
            ext = "mp4"
        }
        return directory.appendingPathComponent("\(safe)-\(kind).\(ext)")
    }

    private func pruneIfNeeded() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        var total: Int64 = 0
        var entries: [(url: URL, size: Int64, date: Date)] = []
        for file in files {
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? .distantPast
            total += size
            entries.append((file, size, date))
        }
        guard total > maxBytes else { return }
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            if total <= maxBytes { break }
            try? fileManager.removeItem(at: entry.url)
            total -= entry.size
        }
    }

    private var directory: URL {
        let root = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return root.appendingPathComponent("ExerciseMedia", isDirectory: true)
    }
}
