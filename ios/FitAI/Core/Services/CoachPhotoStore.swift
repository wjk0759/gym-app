import Foundation
import UIKit

extension AppStore {
    func sendCoachPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        chat.append(
            ChatMessage(
                role: .user,
                text: "请教练看看这张照片，帮我判断动作或器械。",
                imageData: data
            )
        )
        chat.append(
            ChatMessage(
                role: .assistant,
                text: "照片已收到。你想让我重点看动作姿势、器械使用，还是某个部位的不适？再补一句具体问题，我会结合你的训练计划回答。"
            )
        )
        persist()
    }
}
