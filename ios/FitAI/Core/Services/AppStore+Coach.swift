import Foundation

extension AppStore {
    // MARK: - Coach feedback

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
