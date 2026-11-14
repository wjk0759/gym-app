import XCTest

@testable import FitAI

final class CoachChatOrderingTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func message(
        _ role: ChatMessage.Role,
        _ text: String,
        serverID: String,
        date: Date? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: role,
            text: text,
            date: date ?? self.date,
            serverMessageID: serverID
        )
    }

    func testSameTurnPutsUserBeforeAssistant() {
        let assistant = message(.assistant, "reply", serverID: "coach-turn-assistant")
        let user = message(.user, "question", serverID: "coach-turn-user")

        let sorted = CoachChatOrdering.sorted([assistant, user])

        XCTAssertEqual(sorted.map(\.role), [.user, .assistant])
    }

    func testDifferentDatesStayChronological() {
        let later = message(
            .user,
            "later",
            serverID: "2",
            date: date.addingTimeInterval(60)
        )
        let earlier = message(.assistant, "earlier", serverID: "1")

        let sorted = CoachChatOrdering.sorted([later, earlier])

        XCTAssertEqual(sorted.map(\.text), ["earlier", "later"])
    }

    func testSameRoleAndDateUsesStableServerID() {
        let second = message(.user, "second", serverID: "b")
        let first = message(.user, "first", serverID: "a")

        let sorted = CoachChatOrdering.sorted([second, first])

        XCTAssertEqual(sorted.map(\.text), ["first", "second"])
    }
}
