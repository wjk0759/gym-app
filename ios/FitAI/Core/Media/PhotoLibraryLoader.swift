import PhotosUI
import SwiftUI
import UIKit

enum PhotoLibraryLoadError: LocalizedError {
    case unreadable
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这张照片，换一张试试。"
        case .encodeFailed:
            return "照片处理失败，换一张试试。"
        }
    }
}

enum PhotoLibraryLoader {
    /// PhotosPicker 可能返回 HEIC 或超大原图。统一转成方向正确、最长边受限的 JPEG，
    /// 避免后端按 image/jpeg 接收却拿到 HEIC，也避免 8MB 上传限制。
    static func load(
        _ item: PhotosPickerItem,
        maxDimension: CGFloat = 1600,
        compressionQuality: CGFloat = 0.78
    ) async throws -> (image: UIImage, jpegData: Data) {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoLibraryLoadError.unreadable
        }
        let prepared = image.fitWithin(maxDimension: maxDimension)
        guard let jpeg = prepared.jpegData(compressionQuality: compressionQuality) else {
            throw PhotoLibraryLoadError.encodeFailed
        }
        return (prepared, jpeg)
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
}
