import UIKit

/// Normalize camera/photo-library images before sending them to vision.
///
/// PhotoKit can return HEIC data while the upload declares JPEG. Drawing the
/// decoded image into a new JPEG also fixes EXIF orientation, strips metadata
/// and keeps the payload small enough for the vision provider.
enum ImageJPEGNormalizer {
    static func data(
        from image: UIImage,
        maxDimension: CGFloat = 1280,
        quality: CGFloat = 0.8
    ) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return nil
        }

        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height))
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalized.jpegData(compressionQuality: quality)
    }
}
