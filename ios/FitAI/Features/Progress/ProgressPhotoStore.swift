import Foundation
import UIKit

struct ProgressPhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let filename: String
    var note: String
}

/// Local-only progress photos. Images stay in the app's Documents directory
/// and are never uploaded by this store.
enum ProgressPhotoStore {
    private static let folderName = "ProgressPhotos"
    private static let metadataName = "progress-photos.json"

    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    private static var metadataURL: URL {
        directory.appendingPathComponent(metadataName)
    }

    static func load() -> [ProgressPhoto] {
        guard let data = try? Data(contentsOf: metadataURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ProgressPhoto].self, from: data))?
            .sorted { $0.date < $1.date } ?? []
    }

    static func add(image: UIImage, date: Date = Date(), note: String = "") -> ProgressPhoto? {
        ensureDirectory()
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        guard let data = compressedData(image) else { return nil }
        let url = directory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            return nil
        }

        var photos = load()
        let photo = ProgressPhoto(id: id, date: date, filename: filename, note: note)
        photos.append(photo)
        save(photos)
        return photo
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    static func delete(_ photo: ProgressPhoto) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(photo.filename))
        var photos = load()
        photos.removeAll { $0.id == photo.id }
        save(photos)
    }

    static func image(for photo: ProgressPhoto) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(photo.filename).path)
    }

    private static func save(_ photos: [ProgressPhoto]) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(photos) else { return }
        try? data.write(to: metadataURL, options: [.atomic])
    }

    private static func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private static func compressedData(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
