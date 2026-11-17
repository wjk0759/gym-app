import XCTest
@testable import FitAI

final class PlanGenerationCooldownTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshCooldownStartsAtThirtySeconds() {
        XCTAssertEqual(
            PlanGenerationCooldown.remainingSeconds(
                lastGeneratedAt: start,
                now: start
            ),
            30
        )
    }

    func testRemainingSecondsRoundUp() {
        XCTAssertEqual(
            PlanGenerationCooldown.remainingSeconds(
                lastGeneratedAt: start,
                now: start.addingTimeInterval(15.2)
            ),
            15
        )
    }

    func testCooldownEndsAtThirtySeconds() {
        XCTAssertEqual(
            PlanGenerationCooldown.remainingSeconds(
                lastGeneratedAt: start,
                now: start.addingTimeInterval(30)
            ),
            0
        )
        XCTAssertEqual(
            PlanGenerationCooldown.remainingSeconds(
                lastGeneratedAt: start,
                now: start.addingTimeInterval(31)
            ),
            0
        )
    }

    func testNoPreviousGenerationHasNoCooldown() {
        XCTAssertEqual(
            PlanGenerationCooldown.remainingSeconds(lastGeneratedAt: nil),
            0
        )
    }

    func testMessageShowsRemainingSeconds() {
        XCTAssertEqual(
            PlanGenerationCooldown.message(remaining: 17),
            "还需 17 秒才能再次生成计划"
        )
    }
}
