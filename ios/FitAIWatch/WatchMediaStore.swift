import Foundation
import Observation

/// Receives media files from the phone and resolves the clip/poster for the
/// current exercise. Files live in Application Support so they survive a watch
/// reboot while the phone is still in a locker.
@MainActor
@Observable
final class WatchMediaStore {
    static let shared = WatchMediaStore()

    struct Entry: Codable, Hashable {
        var slug: String
        var kind: String
        var fileName: String
        var version: Int
        var sha256: String?
        var loopStartMS: Int?
        var loopEndMS: Int?
    }

    private(set) var revision = 0
    private var entries: [String: Entry] = [:]

    private init() {
        loadIndex()
    }

    func receive(fileURL: URL, metadata: [String: Any]?) -> Bool {
        guard let metadata,
              let slug = metadata["slug"] as? String,
              let kind = metadata["kind"] as? String,
              kind == "video" || kind == "poster" else {
            return false
        }
        let version = (metadata["version"] as? NSNumber)?.intValue ?? 1
        let key = "\(slug):\(kind)"
        if let existing = entries[key], existing.version > version {
            return false
        }
        let size = (try? fileURL.resourceValues(
            forKeys: [.fileSizeKey]
        ))?.fileSize ?? 0
        guard size > 0 else { return false }

        let ext = fileURL.pathExtension.isEmpty
            ? (kind == "video" ? "mp4" : "jpg")
            : fileURL.pathExtension
        let safeSlug = slug.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let fileName = "\(safeSlug)-\(kind)-v\(version).\(ext)"
        let destination = mediaDirectory.appendingPathComponent(fileName)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: fileURL, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = destination
            try? mutable.setResourceValues(values)
        } catch {
            return false
        }

        if let previous = entries[key],
           previous.fileName != fileName {
            try? FileManager.default.removeItem(
                at: mediaDirectory.appendingPathComponent(previous.fileName)
            )
        }
        entries[key] = Entry(
            slug: slug,
            kind: kind,
            fileName: fileName,
            version: version,
            sha256: metadata["sha256"] as? String,
            loopStartMS: (metadata["loopStartMS"] as? NSNumber)?.intValue,
            loopEndMS: (metadata["loopEndMS"] as? NSNumber)?.intValue
        )
        saveIndex()
        revision += 1
        return true
    }

    func videoURL(slug: String) -> URL? {
        url(slug: slug, kind: "video")
    }

    func posterURL(slug: String) -> URL? {
        url(slug: slug, kind: "poster")
    }

    func loopRange(slug: String) -> (start: Double?, end: Double?)? {
        guard let entry = entries["\(slug):video"] else { return nil }
        let start = entry.loopStartMS.map { Double($0) / 1000 }
        let end = entry.loopEndMS.map { Double($0) / 1000 }
        return (start, end)
    }

    /// Remove old exercises after a new day is preloaded, but keep files for
    /// slugs that are still part of today's session.
    func prune(keeping slugs: Set<String>) {
        var changed = false
        for (key, entry) in Array(entries) where !slugs.contains(entry.slug) {
            try? FileManager.default.removeItem(
                at: mediaDirectory.appendingPathComponent(entry.fileName)
            )
            entries.removeValue(forKey: key)
            changed = true
        }
        if changed {
            saveIndex()
            revision += 1
        }
    }

    func clear() {
        for entry in entries.values {
            try? FileManager.default.removeItem(
                at: mediaDirectory.appendingPathComponent(entry.fileName)
            )
        }
        entries.removeAll()
        saveIndex()
        revision += 1
    }

    private func url(slug: String, kind: String) -> URL? {
        guard let entry = entries["\(slug):\(kind)"] else { return nil }
        let url = mediaDirectory.appendingPathComponent(entry.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private var mediaDirectory: URL {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let directory = root.appendingPathComponent(
            "WatchMedia",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private var indexURL: URL {
        mediaDirectory.appendingPathComponent("index.json")
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode(
                  [String: Entry].self,
                  from: data
              ) else {
            return
        }
        entries = decoded
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }
}
