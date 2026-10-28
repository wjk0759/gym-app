import Foundation
import UIKit

extension AppStore {
    /// 教练动作照片点评：真正走后端视觉模型，不再本地假装回复。
    func sendCoachPhoto(
        _ image: UIImage,
        question: String = "请点评动作姿势、器械使用和下一组最需要改的一点。",
        userText: String = "请教练看看这张训练照片，指出动作问题。"
    ) {
        guard let data = image.jpegData(compressionQuality: 0.65) else { return }
        cancelActiveChatRequest()
        agentProposal = nil
        agentActions = []
        agentRunID = nil
        lastAgentRetryText = nil
        pendingUndo = nil
        chat.append(
            ChatMessage(
                role: .user,
                text: userText,
                imageData: data
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
                let result = try await APIClient.shared.reviewCoachVision(
                    imageData: data,
                    question: question
                )
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
                        text: "照片收到了，但这次视觉分析没有完成。你可以先用文字告诉我动作、重量和不适位置，我继续帮你判断。"
                    )
                )
            }
        }
        coachPhotoTask = task

        coachPhotoWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled,
                  let self,
                  self.coachPhotoRequestID == requestID,
                  self.isReplying else { return }
            self.coachPhotoRequestID = nil
            task.cancel()
            self.coachPhotoTask = nil
            self.coachPhotoWatchdog = nil
            self.isReplying = false
            self.chat.append(
                ChatMessage(
                    role: .assistant,
                    text: "这张照片的分析等待太久了，可能是网络或视觉服务较慢。可以重新拍一张，或先用文字描述动作和不舒服的位置。"
                )
            )
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
        if let cue = result.nextCue, !cue.isEmpty {
            parts.append("下一组只盯一件事：\(cue)")
        }
        if !result.isTraining, result.warning == nil {
            parts.append("这张图不太像训练动作；如果你要点评动作，建议拍全身、侧面、光线清楚的一张。")
        }
        return parts.joined(separator: "\n\n")
    }
}
