import SwiftUI

extension CoachChatView {
    private static let feedbackReasons = [
        "inaccurate",
        "unsafe",
        "too_long",
        "not_understood",
        "other",
    ]

    func bubble(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            bubbleContent(message)
            if message.role == .assistant, message.serverMessageID != nil {
                coachFeedbackRow(message)
                    .padding(.leading, 10)
            }
        }
    }

    func coachFeedbackRow(_ message: ChatMessage) -> some View {
        HStack(spacing: 12) {
            if let rating = message.feedbackRating {
                Label(
                    rating == "up" ? "有帮助" : "已反馈",
                    systemImage: rating == "up"
                        ? "hand.thumbsup.fill"
                        : "hand.thumbsdown.fill"
                )
            } else {
                Button {
                    store.submitCoachFeedback(
                        messageID: message.id,
                        rating: "up"
                    )
                } label: {
                    Label("有帮助", systemImage: "hand.thumbsup")
                }

                Menu {
                    ForEach(Self.feedbackReasons, id: \.self) { reason in
                        Button(feedbackReasonTitle(reason)) {
                            store.submitCoachFeedback(
                                messageID: message.id,
                                rating: "down",
                                reason: reason
                            )
                        }
                    }
                } label: {
                    Label("没帮助", systemImage: "hand.thumbsdown")
                }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Theme.tertiaryText)
        .buttonStyle(.plain)
    }

    private func feedbackReasonTitle(_ reason: String) -> String {
        switch reason {
        case "inaccurate": return "不准确"
        case "unsafe": return "不安全"
        case "too_long": return "太长"
        case "not_understood": return "没听懂"
        default: return "其他"
        }
    }
}
