import Foundation

/// Stable ordering for the coach transcript.
///
/// A turn's user message and assistant reply share the same server timestamp.
/// Plain `sort` by date can therefore flip the pair; user messages always come
/// first, then the assistant reply.
enum CoachChatOrdering {
    static func sorted(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted { left, right in
            if left.date != right.date {
                return left.date < right.date
            }
            if left.role != right.role {
                return left.role == .user
            }
            let leftID = left.serverMessageID ?? left.id.uuidString
            let rightID = right.serverMessageID ?? right.id.uuidString
            return leftID < rightID
        }
    }
}
