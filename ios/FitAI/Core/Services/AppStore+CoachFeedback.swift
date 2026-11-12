import Foundation

extension AppStore {
    func submitCoachFeedback(
        messageID: UUID,
        rating: String,
        reason: String? = nil
    ) {
        guard let index = chat.firstIndex(where: { $0.id == messageID }),
              let serverID = chat[index].serverMessageID else {
            return
        }

        let previousRating = chat[index].feedbackRating
        let previousReason = chat[index].feedbackReason
        let runID = chat[index].serverRunID
        chat[index].feedbackRating = rating
        chat[index].feedbackReason = reason
        persist()

        Task { @MainActor in
            do {
                try await APIClient.shared.agentFeedback(
                    messageID: serverID,
                    runID: runID,
                    rating: rating,
                    reason: reason
                )
                toast = rating == "up"
                    ? "已记录：有帮助"
                    : "已记录：会用于改进教练"
            } catch {
                if let current = self.chat.firstIndex(where: {
                    $0.id == messageID
                }) {
                    self.chat[current].feedbackRating = previousRating
                    self.chat[current].feedbackReason = previousReason
                }
                self.toast = "反馈提交失败，请稍后再试"
                self.persist()
            }
        }
    }
}
