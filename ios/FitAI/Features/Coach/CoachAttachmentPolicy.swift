import Foundation

/// Single place for coach attachment limits and validation copy.
///
/// The view should stage attachments, not remember byte limits. Keeping the
/// policy pure also makes it cheap to cover with unit tests later.
enum CoachAttachmentPolicy {
    static let maxImages = 6
    static let maxImageBytes = 8 * 1024 * 1024
    static let maxTotalBytes = 24 * 1024 * 1024

    static func totalBytes(of images: [Data]) -> Int {
        images.reduce(0) { $0 + $1.count }
    }

    static func remainingImageSlots(currentCount: Int) -> Int {
        max(0, maxImages - currentCount)
    }

    static func validationError(appending data: Data, to images: [Data]) -> String? {
        guard images.count < maxImages else {
            return "最多只能添加 \(maxImages) 张照片。"
        }
        guard data.count <= maxImageBytes else {
            return "单张图片不能超过 8MB。"
        }
        guard totalBytes(of: images) + data.count <= maxTotalBytes else {
            return "图片总大小不能超过 24MB。"
        }
        return nil
    }
}
