import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct CoachVideoAttachment: Identifiable {
    let id = UUID()
    let thumbnail: UIImage
    let frames: [Data]
    let durationSeconds: Int
    let analysisPrompt: String
}

enum VideoAttachmentError: LocalizedError {
    case unreadable
    case tooLarge
    case tooShort
    case tooLong
    case noFrames
    case poseFailed
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
        case .poseFailed:
            return "视频姿态识别没有完成，先用画面内容给你判断。"
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
    static let maxFrameBytes = 8 * 1024 * 1024
    static let selectedFrameCount = 6

    private struct VideoSample {
        let time: Double
        let image: UIImage
    }

    private struct PoseFrame {
        let time: Double
        let image: UIImage
        let pointCount: Int
        let confidence: Double
        let fullBody: Bool
        let kneeAngle: Double?
        let torsoLean: Double?
        let leftRightKneeDiff: Double?
        let hipY: Double?
        var motion: Double = 0
    }

    private struct PoseAnalysis {
        let frames: [PoseFrame]
        let peopleCount: Int
        let averageConfidence: Double
        let fullBodyRatio: Double
        let averageMotion: Double
    }

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

        let samples = await Task.detached(priority: .userInitiated) {
            extractSamples(from: url, duration: seconds)
        }.value
        guard !samples.isEmpty else {
            throw VideoAttachmentError.noFrames
        }

        let analysis = await Task.detached(priority: .userInitiated) {
            analyze(samples: samples)
        }.value
        let selected = selectFrames(analysis.frames, count: selectedFrameCount)
        guard !selected.isEmpty else {
            throw VideoAttachmentError.noFrames
        }

        var encodedFrames: [Data] = []
        for frame in selected {
            let prepared = frame.image.fitWithin(maxDimension: 1080)
            guard let data = prepared.jpegData(compressionQuality: 0.78),
                  data.count <= maxFrameBytes else {
                throw VideoAttachmentError.encodeFailed
            }
            encodedFrames.append(data)
        }
        guard encodedFrames.reduce(0, { $0 + $1.count }) <= 24 * 1024 * 1024 else {
            throw VideoAttachmentError.encodeFailed
        }
        guard let thumbnail = selected.first?.image else {
            throw VideoAttachmentError.noFrames
        }

        let prompt = analysisPrompt(
            duration: seconds,
            sampleCount: samples.count,
            frames: selected,
            analysis: analysis
        )

        return CoachVideoAttachment(
            thumbnail: thumbnail,
            frames: encodedFrames,
            durationSeconds: max(1, Int(seconds.rounded())),
            analysisPrompt: prompt
        )
    }

    // MARK: - Sampling and selection

    private static func extractSamples(
        from url: URL,
        duration: Double
    ) -> [VideoSample] {
        let count = min(18, max(6, Int(duration / 0.8) + 1))
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)

        var samples: [VideoSample] = []
        for index in 0..<count {
            let ratio = Double(index) / Double(max(1, count - 1))
            let seconds = max(0.05, min(duration - 0.05, duration * ratio))
            let time = CMTime(seconds: seconds, preferredTimescale: 600)
            guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
                continue
            }
            samples.append(VideoSample(time: seconds, image: UIImage(cgImage: image)))
        }
        return samples
    }

    private static func analyze(samples: [VideoSample]) -> PoseAnalysis {
        var frames: [PoseFrame] = []
        var peopleCount = 0

        for sample in samples {
            guard let cgImage = sample.image.cgImage else { continue }
            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            try? handler.perform([request])
            peopleCount = max(peopleCount, request.results?.count ?? 0)
            guard let observation = request.results?.first else {
                frames.append(
                    PoseFrame(
                        time: sample.time,
                        image: sample.image,
                        pointCount: 0,
                        confidence: 0,
                        fullBody: false,
                        kneeAngle: nil,
                        torsoLean: nil,
                        leftRightKneeDiff: nil,
                        hipY: nil
                    )
                )
                continue
            }

            let points = (try? observation.recognizedPoints(.all)) ?? [:]
            let visible = points.values.filter { $0.confidence > 0.15 }
            let confidence = visible.isEmpty
                ? 0.0
                : visible.reduce(0.0) { $0 + Double($1.confidence) } / Double(visible.count)

            func point(_ name: VNHumanBodyPoseObservation.JointName) -> VNRecognizedPoint? {
                guard let value = points[name], value.confidence > 0.15 else { return nil }
                return value
            }

            let fullBody = point(.nose) != nil
                && point(.leftHip) != nil
                && point(.rightHip) != nil
                && point(.leftKnee) != nil
                && point(.rightKnee) != nil
                && point(.leftAnkle) != nil
                && point(.rightAnkle) != nil

            let leftKneeAngle = angle(point(.leftHip), point(.leftKnee), point(.leftAnkle))
            let rightKneeAngle = angle(point(.rightHip), point(.rightKnee), point(.rightAnkle))
            let kneeAngle: Double?
            if let leftKneeAngle, let rightKneeAngle {
                kneeAngle = (leftKneeAngle + rightKneeAngle) / 2
            } else {
                kneeAngle = leftKneeAngle ?? rightKneeAngle
            }
            let kneeDiff: Double?
            if let leftKneeAngle, let rightKneeAngle {
                kneeDiff = abs(leftKneeAngle - rightKneeAngle)
            } else {
                kneeDiff = nil
            }

            let shoulder = midpoint(point(.leftShoulder), point(.rightShoulder))
            let hip = midpoint(point(.leftHip), point(.rightHip))
            let torsoLean: Double?
            if let shoulder, let hip {
                let dx = shoulder.x - hip.x
                let dy = shoulder.y - hip.y
                let angleFromVertical = abs(atan2(Double(dx), Double(dy)) * 180 / .pi)
                torsoLean = min(90, angleFromVertical)
            } else {
                torsoLean = nil
            }

            frames.append(
                PoseFrame(
                    time: sample.time,
                    image: sample.image,
                    pointCount: visible.count,
                    confidence: confidence,
                    fullBody: fullBody,
                    kneeAngle: kneeAngle,
                    torsoLean: torsoLean,
                    leftRightKneeDiff: kneeDiff,
                    hipY: hip.map { Double($0.y) }
                )
            )
        }

        for index in 1..<frames.count {
            let previous = frames[index - 1]
            let current = frames[index]
            let hipMove = abs((current.hipY ?? previous.hipY ?? 0) - (previous.hipY ?? 0))
            let kneeMove = abs((current.kneeAngle ?? previous.kneeAngle ?? 0) - (previous.kneeAngle ?? 0)) / 180
            frames[index].motion = hipMove + kneeMove
        }

        let visibleFrames = frames.filter { $0.pointCount > 0 }
        let averageConfidence = visibleFrames.isEmpty
            ? 0.0
            : visibleFrames.reduce(0.0) { $0 + $1.confidence } / Double(visibleFrames.count)
        let fullBodyRatio = frames.isEmpty
            ? 0.0
            : Double(frames.filter { $0.fullBody }.count) / Double(frames.count)
        let averageMotion = frames.isEmpty
            ? 0.0
            : frames.reduce(0.0) { $0 + $1.motion } / Double(frames.count)

        return PoseAnalysis(
            frames: frames,
            peopleCount: peopleCount,
            averageConfidence: averageConfidence,
            fullBodyRatio: fullBodyRatio,
            averageMotion: averageMotion
        )
    }

    private static func selectFrames(_ frames: [PoseFrame], count: Int) -> [PoseFrame] {
        guard frames.count > count else { return frames }
        let chronological = frames.sorted { $0.time < $1.time }
        let visible = chronological.filter { $0.pointCount > 0 }
        let candidates = visible.isEmpty ? chronological : visible
        guard candidates.count > count else { return candidates }

        var selected = Set<Int>()
        selected.insert(0)
        selected.insert(candidates.count - 1)

        func add(_ index: Int?) {
            guard let index, selected.count < count else { return }
            selected.insert(index)
        }

        // Pick the frames with the most useful pose evidence first.
        add(candidates.indices.min {
            (candidates[$0].kneeAngle ?? 999) < (candidates[$1].kneeAngle ?? 999)
        })
        add(candidates.indices.max {
            (candidates[$0].kneeAngle ?? -1) < (candidates[$1].kneeAngle ?? -1)
        })
        add(candidates.indices.max {
            (candidates[$0].torsoLean ?? -1) < (candidates[$1].torsoLean ?? -1)
        })
        add(candidates.indices.max {
            candidates[$0].motion < candidates[$1].motion
        })
        add(candidates.indices.max {
            (candidates[$0].leftRightKneeDiff ?? -1) < (candidates[$1].leftRightKneeDiff ?? -1)
        })

        var cursor = 1
        while selected.count < count, cursor < candidates.count {
            add(cursor)
            cursor += 1
        }

        return selected.sorted().map { candidates[$0] }
    }

    private static func analysisPrompt(
        duration: Double,
        sampleCount: Int,
        frames: [PoseFrame],
        analysis: PoseAnalysis
    ) -> String {
        var lines = [
            "这是一段 \(String(format: "%.1f", duration)) 秒的训练视频。",
            "手机本地采样了 \(sampleCount) 个画面，选出 \(frames.count) 个关键帧（按时间顺序上传）。",
            "请结合画面和下面的姿态指标判断；只对可见内容下结论，不确定时明确说明。"
        ]

        if analysis.peopleCount > 1 {
            lines.append("画面中检测到多人，主要观察最居中、最完整的主体。")
        }
        if analysis.averageConfidence < 0.35 {
            lines.append("姿态关键点置信度偏低，角度和左右对称判断可信度有限。")
        }
        if analysis.fullBodyRatio < 0.4 {
            lines.append("很多关键帧没有完整全身/脚踝，深度和整体姿势只能作为参考。")
        }
        if analysis.averageMotion < 0.02 {
            lines.append("画面中动作变化不明显，可能不是完整动作或镜头没有跟随。")
        }

        let kneeAngles = frames.compactMap { $0.kneeAngle }
        if let minimum = kneeAngles.min(), let maximum = kneeAngles.max() {
            lines.append("可见膝关节角度范围：\(Int(minimum.rounded()))°–\(Int(maximum.rounded()))°。")
        }
        if let maxLean = frames.compactMap({ $0.torsoLean }).max() {
            lines.append("最大躯干偏离垂直角度：约 \(Int(maxLean.rounded()))°。")
        }
        if let maxDiff = frames.compactMap({ $0.leftRightKneeDiff }).max() {
            lines.append("左右膝关节最大角度差：约 \(Int(maxDiff.rounded()))°。")
        }
        if frames.allSatisfy({ $0.pointCount == 0 }) {
            lines.append("本地没有稳定识别到人体；如果画面主要是器械、食物或其他内容，请如实指出。")
        }
        let times = frames.map { String(format: "%.1fs", $0.time) }.joined(separator: "、")
        lines.append("关键帧时间点：\(times)。")
        lines.append("如果视频里的动作名称、重量或疼痛信息不明确，只需要问一个最关键的问题，不要编造。")
        return lines.joined(separator: "\n")
    }

    private static func point(
        _ a: VNRecognizedPoint?,
        _ b: VNRecognizedPoint?
    ) -> VNRecognizedPoint? {
        guard let a else { return b }
        guard let b else { return a }
        return a.confidence >= b.confidence ? a : b
    }

    private static func midpoint(
        _ a: VNRecognizedPoint?,
        _ b: VNRecognizedPoint?
    ) -> CGPoint? {
        guard let a, let b else { return nil }
        return CGPoint(
            x: (a.location.x + b.location.x) / 2,
            y: (a.location.y + b.location.y) / 2
        )
    }

    private static func angle(
        _ a: VNRecognizedPoint?,
        _ b: VNRecognizedPoint?,
        _ c: VNRecognizedPoint?
    ) -> Double? {
        guard let a, let b, let c else { return nil }
        let first = CGPoint(x: a.location.x - b.location.x, y: a.location.y - b.location.y)
        let second = CGPoint(x: c.location.x - b.location.x, y: c.location.y - b.location.y)
        let dot = Double(first.x * second.x + first.y * second.y)
        let firstLength = hypot(Double(first.x), Double(first.y))
        let secondLength = hypot(Double(second.x), Double(second.y))
        guard firstLength > 0.0001, secondLength > 0.0001 else { return nil }
        let cosine = max(-1, min(1, dot / (firstLength * secondLength)))
        return acos(cosine) * 180 / .pi
    }
}
