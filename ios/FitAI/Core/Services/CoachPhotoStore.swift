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
        chat.append(
            ChatMessage(
                role: .user,
                text: userText,
                imageData: data
            )
        )
        isReplying = true
        persist()

        Task { @MainActor in
            do {
                let result = try await APIClient.shared.reviewCoachVision(
                    imageData: data,
                    question: question
                )
                chat.append(
                    ChatMessage(role: .assistant, text: formattedVisionReply(result))
                )
            } catch {
                chat.append(
                    ChatMessage(
                        role: .assistant,
                        text: "照片收到了，但这次视觉分析没有完成。你可以先用文字告诉我动作、重量和不适位置，我继续帮你判断。"
                    )
                )
            }
            isReplying = false
            persist()
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
