import Foundation

extension AppStore {
    // MARK: - Coach feedback

    /// Legacy `/coach/chat` context: keep body analysis and the latest visual
    /// memory together instead of letting one overwrite the other.
    var coachContextForReply: String? {
        let parts = [coachContext, coachVisualMemory?.promptText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
    }

    /// 把教练能力的执行结果写回对话，保持“结果留在教练页”的闭环。
    func appendCoachNotice(_ text: String) {
        chat.append(ChatMessage(role: .assistant, text: text))
        persist()
    }

    /// 其他入口把照片交给教练时，只进入教练页的待发送区，不替用户发送。
    func queueCoachAttachment(_ data: Data) {
        guard !data.isEmpty else { return }
        pendingCoachAttachmentData.append(data)
        selectedTab = 2
    }
}
