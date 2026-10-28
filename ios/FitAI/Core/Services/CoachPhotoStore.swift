import Foundation
import UIKit

extension AppStore {
    /// 单图入口，保留给 Discover / 视频点评等已有页面。
    func sendCoachPhoto(
        _ image: UIImage,
        question: String = "请分析这张图片：如果涉及训练动作、饮食、器械或体型，按相应角度回答。",
        userText: String = ""
    ) {
        guard let data = image.jpegData(compressionQuality: 0.65) else { return }
        sendCoachPhotos([data], caption: userText, question: question)
    }

    /// 教练页附件发送：图片先进入等待区，用户确认后再调用这里。
    /// caption 为空时只显示图片，不再伪造“请教练看看这张训练照片”的用户文字。
    func sendCoachPhotos(
        _ imageData: [Data],
        caption: String,
        question: String? = nil,
        videoThumbnailData: Data? = nil,
        videoDurationSeconds: Int? = nil
    ) {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = Array(imageData.prefix(6))
        guard !images.isEmpty else { return }

        let customQuestion = (question ?? trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        let visionQuestion = customQuestion.isEmpty
            ? "请先判断图片内容：如果是训练动作，点评姿势并给一个最重要的改进点；如果是食物，估算热量和营养；如果是器械，说明用途和替代；如果是其他内容，如实说明。"
            : customQuestion

        cancelActiveChatRequest()
        removeTrailingChatTimeoutNotices()
        agentProposal = nil
        agentActions = []
        agentRunID = nil
        lastAgentRetryText = nil
        pendingUndo = nil
        chat.append(
            ChatMessage(
                role: .user,
                text: trimmed,
                imageDataList: videoThumbnailData == nil ? images : nil,
                videoThumbnailData: videoThumbnailData,
                videoDurationSeconds: videoDurationSeconds
            )
        )

        let requestID = UUID()
        coachPhotoRequestID = requestID
        isReplying = true
        persist()

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.coachPhotoRequestID == requestID {
                    self.coachPhotoRequestID = nil
                    self.coachPhotoTask = nil
                    self.coachPhotoWatchdog?.cancel()
                    self.coachPhotoWatchdog = nil
                    self.isReplying = false
                    self.persist()
                }
            }
            do {
                let result: CoachVisionResult
                if images.count == 1 {
                    result = try await APIClient.shared.reviewCoachVision(
                        imageData: images[0],
                        question: visionQuestion
                    )
                } else {
                    result = try await APIClient.shared.reviewCoachVisionBatch(
                        imageData: images,
                        question: visionQuestion
                    )
                }
                try Task.checkCancellation()
                self.chat.append(
                    ChatMessage(role: .assistant, text: self.formattedVisionReply(result))
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "附件收到了，但这次视觉分析没有完成。你可以先用文字补充问题，我继续帮你判断。"
                    )
                )
            }
        }
        coachPhotoTask = task

        coachPhotoWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: AppStore.chatRequestTimeoutNanoseconds)
            guard !Task.isCancelled,
                  let self,
                  self.coachPhotoRequestID == requestID,
                  self.isReplying else { return }
            self.coachPhotoRequestID = nil
            task.cancel()
            self.coachPhotoTask = nil
            self.coachPhotoWatchdog = nil
            self.isReplying = false
            self.chat.append(ChatMessage(role: .assistant, text: AppStore.photoTimeoutNotice))
            self.persist()
        }
    }

    private func formattedVisionReply(_ result: CoachVisionResult) -> String {
        var parts: [String] = []
        if result.safetyFlag == "medical_referral" {
            parts.append("先停一下：这张照片/描述里可能有需要线下评估的风险，不建议继续加练。")
        }
        parts.append(result.summary)
        if !result.observations.isEmpty {
            parts.append("我看到：\n" + result.observations.map { "· \($0)" }.joined(separator: "\n"))
        }

        let mode = (result.mode ?? (result.isTraining ? "training" : "general")).lowercased()
        if mode == "training" {
            if result.isTraining, let cue = result.nextCue, !cue.isEmpty {
                parts.append("下一组先改：\(cue)")
            } else if result.warning == nil {
                parts.append("这组附件不太像训练动作；如果你要点评动作，建议拍全身、侧面、光线清楚的一张。")
            }
        }
        return parts.joined(separator: "\n\n")
    }
}
