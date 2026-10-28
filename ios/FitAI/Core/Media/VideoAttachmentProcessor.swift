import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

struct CoachVideoAttachment: Identifiable {
    let id = UUID()
    let thumbnail: UIImage
    let contactSheetData: Data
    let durationSeconds: Int
}

enum VideoAttachmentError: LocalizedError {
    case unreadable
    case tooLarge
    case tooShort
    case tooLong
    case noFrames
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这个视频，换一段试试。"
        case .tooLarge:
            return "视频不能超过 200MB，建议截取 5–40 秒的片段。"
        case .tooShort:
            return "视频太短，至少需要 1 秒。"
        case .tooLong:
            return "视频不要超过 3 分钟，截取关键片段即可。"
        case .noFrames:
            return "没有抽取到有效画面，换一段视频试试。"
        case .encodeFailed:
            return "视频关键帧处理失败，换一段视频试试。"
        }
    }
}

struct CoachVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let target = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(
                    received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
                )
            try FileManager.default.copyItem(at: received.file, to: target)
            return CoachVideoFile(url: target)
        }
    }
}

enum VideoAttachmentProcessor {
    static let maxVideoBytes = 200 * 1024 * 1024
    static let maxDurationSeconds = 180.0
    static let maxContactSheetBytes = 8 * 1024 * 1024

    static func prepare(_ item: PhotosPickerItem) async throws -> CoachVideoAttachment {
        guard let file = try await item.loadTransferable(type: CoachVideoFile.self) else {
            throw VideoAttachmentError.unreadable
        }
        let url = file.url
        defer { try? FileManager.default.removeItem(at: url) }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        guard bytes <= maxVideoBytes else {
            throw VideoAttachmentError.tooLarge
        }

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0.5 else {
            throw VideoAttachmentError.tooShort
        }
        guard seconds <= maxDurationSeconds else {
            throw VideoAttachmentError.tooLong
        }

        let frames = await Task.detached(priority: .userInitiated) {
            extractFrames(from: url, seconds: seconds)
        }.value
        guard let thumbnail = frames.images.first, !frames.images.isEmpty else {
            throw VideoAttachmentError.noFrames
        }

        let contactSheet = await Task.detached(priority: .userInitiated) {
            makeContactSheet(frames.images, times: frames.times)
        }.value
        guard let data = contactSheet.jpegData(compressionQuality: 0.82),
              data.count <= maxContactSheetBytes else {
            throw VideoAttachmentError.encodeFailed
        }

        return CoachVideoAttachment(
            thumbnail: thumbnail,
            contactSheetData: data,
            durationSeconds: max(1, Int(seconds.rounded()))
        )
    }

    private static func extractFrames(
        from url: URL,
        seconds: Double
    ) -> (images: [UIImage], times: [Int]) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)
        var images: [UIImage] = []
        var times: [Int] = []
        for ratio in [0.2, 0.5, 0.8] {
            let time = CMTime(seconds: max(0.1, seconds * ratio), preferredTimescale: 600)
            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                images.append(UIImage(cgImage: image))
                times.append(Int(seconds * ratio))
            } catch {
                // One missing frame is fine; the other frames still describe the motion.
            }
        }
        return (images, times)
    }

    private static func makeContactSheet(_ images: [UIImage], times: [Int]) -> UIImage {
        let width: CGFloat = 720
        let frameHeight = width * 9 / 16
        let size = CGSize(width: width, height: frameHeight * CGFloat(images.count))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            for (index, image) in images.enumerated() {
                let rect = CGRect(
                    x: 0,
                    y: CGFloat(index) * frameHeight,
                    width: width,
                    height: frameHeight
                )
                let scale = max(rect.width / image.size.width, rect.height / image.size.height)
                let drawSize = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                let drawRect = CGRect(
                    x: rect.midX - drawSize.width / 2,
                    y: rect.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
                image.draw(in: drawRect)

                let label = "\(times.indices.contains(index) ? times[index] : 0)s"
                label.draw(
                    at: CGPoint(x: 16, y: rect.minY + 16),
                    withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white
                    ]
                )
            }
        }
    }
}
