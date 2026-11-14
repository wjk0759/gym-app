import XCTest
@testable import FitAI

final class CoachTurnMessageIDTests: XCTestCase {
    func testExtractsTurnIDFromAssistantHistoryID() {
        let turnID = "0c851749-0ac8-45b3-8295-44c5c85f7a9f"
        XCTAssertEqual(
            CoachTurnMessageID.turnID(from: "coach-\(turnID)-assistant"),
            turnID
        )
        XCTAssertEqual(
            CoachTurnMessageID.turnID(from: "coach-\(turnID)-user"),
            nil
        )
    }

    func testIgnoresLegacyMessageIDs() {
        XCTAssertNil(CoachTurnMessageID.turnID(from: "b4b1c3d2-0000-0000-0000-000000000000"))
        XCTAssertNil(CoachTurnMessageID.turnID(from: "coach-not-a-uuid-assistant"))
        XCTAssertNil(CoachTurnMessageID.turnID(from: "coach--assistant"))
    }
}
