import SwiftUI
import UIKit

/// Creates a shareable before/after card. Everything is rendered locally; the
/// exporter never uploads the source photos.
enum ProgressPhotoExporter {
    static func comparisonImage(
        before: ProgressPhoto,
        after: ProgressPhoto,
        beforeImage: UIImage,
        afterImage: UIImage
    ) -> UIImage? {
        let size = CGSize(width: 1200, height: 1500)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let paper = UIColor(red: 0.957, green: 0.941, blue: 0.902, alpha: 1)
            let ink = UIColor(red: 0.070, green: 0.075, blue: 0.055, alpha: 1)
            let cobalt = UIColor(red: 0.180, green: 0.290, blue: 1.000, alpha: 1)
            let lime = UIColor(red: 0.370, green: 0.480, blue: 0.000, alpha: 1)

            paper.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            drawText(
                "PROGRESS / 变化",
                at: CGPoint(x: 60, y: 56),
                font: .systemFont(ofSize: 24, weight: .bold),
                color: cobalt
            )
            drawText(
                "放在一起看",
                at: CGPoint(x: 60, y: 94),
                font: .systemFont(ofSize: 58, weight: .black),
                color: ink
            )
            drawText(
                "同一角度、同一光线，变化才有意义。",
                at: CGPoint(x: 60, y: 168),
                font: .systemFont(ofSize: 22, weight: .regular),
                color: ink.withAlphaComponent(0.62)
            )

            let imageTop: CGFloat = 260
            let imageSize = CGSize(width: 500, height: 1040)
            drawPhoto(
                beforeImage,
                in: CGRect(origin: CGPoint(x: 60, y: imageTop), size: imageSize),
                label: "开始  \(dateLabel(before.date))",
                labelColor: cobalt,
                context: context
            )
            drawPhoto(
                afterImage,
                in: CGRect(origin: CGPoint(x: 640, y: imageTop), size: imageSize),
                label: "现在  \(dateLabel(after.date))",
                labelColor: lime,
                context: context
            )

            drawText(
                "FitAI · 练途 · 照片只保存在本机",
                at: CGPoint(x: 60, y: 1392),
                font: .systemFont(ofSize: 20, weight: .semibold),
                color: ink.withAlphaComponent(0.45)
            )
        }
    }

    private static func drawPhoto(
        _ image: UIImage,
        in rect: CGRect,
        label: String,
        labelColor: UIColor,
        context: UIGraphicsImageRendererContext
    ) {
        let ink = UIColor(red: 0.070, green: 0.075, blue: 0.055, alpha: 1)
        drawText(
            label,
            at: CGPoint(x: rect.minX, y: rect.minY - 36),
            font: .systemFont(ofSize: 21, weight: .bold),
            color: labelColor
        )

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 24)
        context.cgContext.saveGState()
        path.addClip()
        drawAspectFill(image, in: rect)
        context.cgContext.restoreGState()

        path.lineWidth = 3
        ink.withAlphaComponent(0.18).setStroke()
        path.stroke()
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        image.draw(in: CGRect(origin: origin, size: size))
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor
    ) {
        (text as NSString).draw(
            at: point,
            withAttributes: [
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

/// UIKit share sheet for the rendered comparison image.
struct ProgressPhotoActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
