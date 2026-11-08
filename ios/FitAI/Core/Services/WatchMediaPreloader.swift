import Foundation
import FitAIWorkoutCore
import WatchConnectivity

/// Downloads the watch derivatives on the phone and hands them to
/// WatchConnectivity's durable file queue. The watch never streams media while
/// the phone is in a locker, so only files received here are playable offline.
@MainActor
final class WatchMediaPreloader {
    private let fileManager = FileManager.default

    private var cacheDirectory: URL {
        let root = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = root.appendingPathComponent(
            "FitAIWatchMedia",
            isDirectory: true
        )
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    func preload(media: [WatchMediaAsset], session: WCSession) async {
        guard session.isWatchAppInstalled else { return }
        for item in media {
            if let video = item.watchURL,
               let file = await download(
                   video,
                   slug: item.exerciseSlug,
                   version: item.version,
                   sha256: item.sha256,
                   kind: "video"
               ) {
                transfer(
                    file,
                    session: session,
                    item: item,
                    kind: "video"
                )
            }
            if let poster = item.posterURL,
               let file = await download(
                   poster,
                   slug: item.exerciseSlug,
                   version: item.version,
                   sha256: item.sha256,
                   kind: "poster"
               ) {
                transfer(
                    file,
                    session: session,
                    item: item,
                    kind: "poster"
                )
            }
        }
    }

    private func transfer(
        _ file: URL,
        session: WCSession,
        item: WatchMediaAsset,
        kind: String
    ) {
        var metadata: [String: Any] = [
            "kind": kind,
            "slug": item.exerciseSlug,
            "version": item.version
        ]
        if let sha = item.sha256 { metadata["sha256"] = sha }
        if let start = item.loopStartMS { metadata["loopStartMS"] = start }
        if let end = item.loopEndMS { metadata["loopEndMS"] = end }
        session.transferFile(file, metadata: metadata)
    }

    private func download(
        _ url: URL,
        slug: String,
        version: Int,
        sha256: String?,
        kind: String
    ) async -> URL? {
        let fingerprint = sha256.map { String($0.prefix(12)) } ?? "v\(version)"
        let ext = url.pathExtension.isEmpty
            ? (kind == "video" ? "mp4" : "jpg")
            : url.pathExtension
        let safeSlug = slug.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        let destination = cacheDirectory.appendingPathComponent(
            "\(safeSlug)-\(kind)-\(fingerprint).\(ext)"
        )
        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        do {
            let (temporary, response) = try await URLSession.shared.download(
                from: url
            )
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                try? fileManager.removeItem(at: temporary)
                return nil
            }
            if http.expectedContentLength > 80 * 1024 * 1024 {
                try? fileManager.removeItem(at: temporary)
                return nil
            }
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporary, to: destination)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = destination
            try? mutable.setResourceValues(values)
            return destination
        } catch {
            return nil
        }
    }
}
