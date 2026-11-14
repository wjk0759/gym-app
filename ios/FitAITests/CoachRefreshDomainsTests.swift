import XCTest

@testable import FitAI

final class CoachRefreshDomainsTests: XCTestCase {
    func testServerDomainsWin() {
        let domains = CoachRefreshDomains.domains(
            for: "training.reschedule",
            server: ["plan", "workouts", "unknown"]
        )

        XCTAssertEqual(domains, [.plan, .workouts])
    }

    func testFallbackCoversWorkoutAndDietWrites() {
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "training.log_strength"),
            [.workouts, .plan, .schedule, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "diet.generate_week"),
            [.diet]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "body.log_weight"),
            [.body, .profile, .review]
        )
    }

    func testUnknownCapabilityRefreshesNothing() {
        XCTAssertTrue(
            CoachRefreshDomains.domains(for: "coach.answer").isEmpty
        )
    }
}
