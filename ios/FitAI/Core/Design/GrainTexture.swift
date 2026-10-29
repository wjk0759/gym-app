import SwiftUI
import UIKit

/// A tiny tiled noise texture for cinematic grain.
///
/// The image is generated once at 3x and tiled by Core Animation. It is a static
/// layer: no Canvas, no per-frame drawing, and no blur.
struct GrainTexture: View {
    var opacity: Double = 0.035

    var body: some View {
        Image(uiImage: Self.texture)
            .resizable(resizingMode: .tile)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let texture: UIImage = makeTexture()

    private static func makeTexture() -> UIImage {
        let pixelSize = 192
        let bytesPerPixel = 4
        let bytesPerRow = pixelSize * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: bytesPerRow * pixelSize)
        var seed: UInt32 = 0x9E37_79B9

        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let value = UInt8(truncatingIfNeeded: seed >> 24)
            pixels[index] = value
            pixels[index + 1] = value
            pixels[index + 2] = value
            pixels[index + 3] = 255
        }

        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        return UIImage(cgImage: image, scale: 3, orientation: .up)
    }
}
