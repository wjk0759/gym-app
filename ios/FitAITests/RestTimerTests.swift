import XCTest

@testable import FitAI

final class RestTimerTests: XCTestCase {
    func testRestRemainingRoundsUpAndClampsAtZero() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            WorkoutSessionView.restRemaining(
                until: now.addingTimeInterval(0.2),
                now: now
            ),
            1
        )
        XCTAssertEqual(
            WorkoutSessionView.restRemaining(
                until: now.addingTimeInterval(30),
                now: now
            ),
            30
        )
        XCTAssertEqual(
            WorkoutSessionView.restRemaining(until: now, now: now),
            0
        )
        XCTAssertEqual(
            WorkoutSessionView.restRemaining(
                until: now.addingTimeInterval(-5),
                now: now
            ),
            0
        )
    }
}
