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
            [.body, .profile, .diet, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "body.delete_metric"),
            [.body, .profile, .diet, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "diet.favorite_food"),
            [.profile]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "diet.custom_food"),
            [.profile]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "diet.delete_log"),
            [.diet, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "training.update_workout"),
            [.workouts, .plan, .schedule, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "training.configure_plan"),
            [.plan, .schedule, .workouts, .diet]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "memory.remember"),
            [.profile]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "diet.log_planned_meal"),
            [.diet, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "training.skip"),
            [.plan, .schedule, .review]
        )
        XCTAssertEqual(
            CoachRefreshDomains.domains(for: "training.add_plan_day"),
            [.plan, .schedule, .workouts, .review]
        )
    }

    func testUnknownCapabilityRefreshesNothing() {
        XCTAssertTrue(
            CoachRefreshDomains.domains(for: "coach.answer").isEmpty
        )
    }
}
