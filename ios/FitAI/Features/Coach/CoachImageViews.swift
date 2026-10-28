import ImageIO
import SwiftUI
import UIKit

struct ChatMessageImageGrid: View {
    let messageID: UUID
    let images: [Data]

    var body: some View {
        if images.count == 1 {
            ChatImageThumbnail(
                messageID: messageID,
                data: images[0],
                width: 240,
                height: 160
            )
        } else {
            LazyVGrid(
                columns: [
                    GridItem(.fixed(104), spacing: 6),
                    GridItem(.fixed(104), spacing: 6)
                ],
                spacing: 6
            ) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    ChatImageThumbnail(
                        messageID: messageID,
                        data: data,
                        cacheKeySuffix: String(index),
                        width: 104,
                        height: 104
                    )
                }
            }
            .frame(width: 214, alignment: .leading)
        }
    }
}

struct ChatVideoThumbnail: View {
    let messageID: UUID
    let data: Data
    let duration: Int

    var body: some View {
        ChatImageThumbnail(
            messageID: messageID,
            data: data,
            cacheKeySuffix: "video",
            width: 240,
            height: 160
        )
        .overlay {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))
                .shadow(radius: 3)
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(duration)s")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.62), in: Capsule())
                .padding(7)
        }
    }
}

struct ChatImageThumbnail: View {
    let messageID: UUID
    let data: Data
    var cacheKeySuffix: String = ""
    var width: CGFloat = 240
    var height: CGFloat = 160

    @State private var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surfaceStrong)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: messageID.uuidString + cacheKeySuffix) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        let key = (messageID.uuidString + cacheKeySuffix) as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        let payload = data
        let decoded = await Task.detached(priority: .userInitiated) {
            Self.downsample(payload, maxPixel: 480)
        }.value
        guard let decoded else { return }
        Self.cache.setObject(decoded, forKey: key)
        image = decoded
    }

    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
