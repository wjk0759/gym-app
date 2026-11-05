import PhotosUI
import SwiftUI
import UIKit

enum PhotoLibraryLoadError: LocalizedError {
    case unreadable
    case encodeFailed
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这张照片，换一张试试。"
        case .encodeFailed:
            return "照片处理失败，换一张试试。"
        case .tooLarge:
            return "照片压缩后仍然太大，请换一张小于 8MB 的照片。"
        }
    }
}

enum PhotoLibraryLoader {
    /// PhotosPicker 可能返回 HEIC 或超大原图。统一转成方向正确、最长边受限的 JPEG，
    /// 避免后端按 image/jpeg 接收却拿到 HEIC，也避免 8MB 上传限制。
    static func load(
        _ item: PhotosPickerItem,
        maxDimension: CGFloat = 1600,
        compressionQuality: CGFloat = 0.78,
        maxBytes: Int = 8 * 1024 * 1024
    ) async throws -> (image: UIImage, jpegData: Data) {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoLibraryLoadError.unreadable
        }
        let prepared = image.fitWithin(maxDimension: maxDimension)
        guard let jpeg = prepared.jpegData(compressionQuality: compressionQuality) else {
            throw PhotoLibraryLoadError.encodeFailed
        }
        guard jpeg.count <= maxBytes else {
            throw PhotoLibraryLoadError.tooLarge
        }
        return (prepared, jpeg)
    }

    /// Avatars are square and small; re-encoding strips location metadata.
    static func loadAvatar(_ item: PhotosPickerItem) async throws -> Data {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoLibraryLoadError.unreadable
        }
        return try prepareAvatar(image)
    }

    static func prepareAvatar(
        _ image: UIImage,
        maxDimension: CGFloat = 512,
        maxBytes: Int = 2 * 1024 * 1024
    ) throws -> Data {
        let square = image.squareCropped(maxDimension: maxDimension)
        guard let jpeg = square.jpegData(compressionQuality: 0.86) else {
            throw PhotoLibraryLoadError.encodeFailed
        }
        guard jpeg.count <= maxBytes else {
            throw PhotoLibraryLoadError.tooLarge
        }
        return jpeg
    }
}

extension UIImage {
    func fitWithin(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else {
            return self
        }
        let scale = maxDimension / longestSide
        let target = CGSize(
            width: max(1, (size.width * scale).rounded()),
            height: max(1, (size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func squareCropped(maxDimension: CGFloat) -> UIImage {
        let side = min(size.width, size.height)
        guard side > 0 else { return self }
        let target = min(side, maxDimension)
        let scale = target / side
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(
            size: CGSize(width: target, height: target),
            format: format
        ).image { _ in
            draw(in: CGRect(
                x: (target - drawSize.width) / 2,
                y: (target - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }
    }
}
