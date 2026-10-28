import AVFoundation
import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// 训练视频点评：本地抽 3 个关键帧拼成一张图，再交给教练视觉模型。
/// 原视频不上传，只上传联系表，减少流量和隐私风险。
struct VideoReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var videoItem: PhotosPickerItem?
    @State private var contactSheet: UIImage?
    @State private var duration: Double = 0
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var note = ""

    private struct VideoFile: Transferable {
        let url: URL

        static var transferRepresentation: some TransferRepresentation {
            FileRepresentation(contentType: .movie) { video in
                SentTransferredFile(video.url)
            } importing: { received in
                let target = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension)
                try FileManager.default.copyItem(at: received.file, to: target)
                return VideoFile(url: target)
            }
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    pickerCard

                    if isProcessing {
                        processingCard
                    } else if let contactSheet {
                        previewCard(contactSheet)
                        noteCard
                        Button {
                            send(contactSheet)
                        } label: {
                            Text("发给教练点评")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                            .card(padding: 14)
                    }

                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("视频动作点评")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: videoItem?.itemIdentifier) { _, _ in
                guard let videoItem else { return }
                Task { await prepare(videoItem) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("发一段视频，\n让教练看动作。")
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("本地抽取开始、中段、结束 3 个关键帧，指出最值得改的一处。原视频不会上传。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PhotosPicker(selection: $videoItem, matching: .videos) {
                Label("选择训练视频", systemImage: "video.badge.plus")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("建议 5–40 秒、全身侧面、光线清楚。超过 1 分钟也可以，但只抽取 3 帧。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var processingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("正在抽取关键帧…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("视频只在本机处理")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card()
    }

    private func previewCard(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("关键帧预览")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(Int(duration)) 秒")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.tertiaryText)
            }
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 0.8)
                )
        }
        .card()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("想让教练重点看什么？")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            TextField("例如：卧推时肩膀不舒服 / 深蹲膝盖内扣", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: note) { _, value in
                    if value.count > 200 {
                        note = String(value.prefix(200))
                    }
                }
        }
        .card()
    }

    private var privacyNote: some View {
        Text("视频抽帧在本机完成，原视频不上传；只把 3 帧拼图和你的问题发给教练。涉及明显疼痛、肿胀或无法承重，请先停止训练并线下就医。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @MainActor
    private func prepare(_ item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = ""
        contactSheet = nil
        var tempURL: URL?
        do {
            guard let file = try await item.loadTransferable(type: VideoFile.self) else {
                throw ReviewError("无法读取这个视频")
            }
            tempURL = file.url
            let asset = AVURLAsset(url: file.url)
            let loadedDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(loadedDuration)
            guard seconds.isFinite, seconds > 0.5 else {
                throw ReviewError("视频太短，至少需要 1 秒")
            }

            let url = file.url
            let frames = await Task.detached(priority: .userInitiated) {
                Self.extractFrames(from: url, seconds: seconds)
            }.value
            guard !frames.images.isEmpty else {
                throw ReviewError("没有抽取到有效画面，换一段视频试试")
            }

            let images = frames.images
            let times = frames.times
            contactSheet = await Task.detached(priority: .userInitiated) {
                Self.makeContactSheet(images, times: times)
            }.value
            duration = seconds
        } catch {
            errorMessage = (error as? ReviewError)?.message ?? "视频处理失败，换一段视频试试"
        }
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        isProcessing = false
    }

    private static func extractFrames(from url: URL, seconds: Double) -> (images: [UIImage], times: [Int]) {
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
                // 视频尾部/关键帧缺失时跳过这一帧，其他帧仍可用。
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

                let label = "\(times[safe: index] ?? 0)s"
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

    private func send(_ image: UIImage) {
        let noteText = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let question = """
        这是一段 \(Int(duration)) 秒训练视频的 3 个关键帧拼图（从上到下按时间）。
        请结合画面逐帧指出动作问题，并只给下一组最重要的一个提示。
        \(noteText.isEmpty ? "" : "用户补充：\(noteText)")
        """
        store.sendCoachPhoto(
            image,
            question: question,
            userText: "请教练点评这段训练视频的截帧。"
        )
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            store.selectedTab = 2
        }
    }
}

private struct ReviewError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
