import XCTest

@testable import FitAI

final class AppDataDependencyTests: XCTestCase {
    func testBodyMetricInvalidatesTargetsAndReview() {
        let dependency = AppDataChange.bodyMetric.dependency

        XCTAssertEqual(
            dependency.domains,
            [.body, .profile, .diet, .review]
        )
        XCTAssertTrue(dependency.invalidatesTargets)
        XCTAssertFalse(dependency.reschedulesNotifications)
    }

    func testProfileChangeRefreshesBodyDietAndReview() {
        let dependency = AppDataChange.profile.dependency

        XCTAssertEqual(
            dependency.domains,
            [.profile, .body, .diet, .review]
        )
        XCTAssertTrue(dependency.invalidatesTargets)
    }

    func testFoodAndWorkoutUpdatesRefreshReview() {
        XCTAssertEqual(
            AppDataChange.foodLog.dependency.domains,
            [.diet, .review]
        )
        XCTAssertEqual(
            AppDataChange.workout.dependency.domains,
            [.workouts, .plan, .schedule, .review]
        )
    }

    func testPlanChangeInvalidatesTargetsAndReschedulesNotifications() {
        let dependency = AppDataChange.plan.dependency

        XCTAssertEqual(
            dependency.domains,
            [.plan, .schedule, .diet, .workouts, .review]
        )
        XCTAssertTrue(dependency.invalidatesTargets)
        XCTAssertTrue(dependency.reschedulesNotifications)
    }

    func testEquipmentAndBodyAnalysisStaySeparate() {
        XCTAssertEqual(
            AppDataChange.equipment.dependency.domains,
            [.equipment, .plan]
        )
        XCTAssertEqual(
            AppDataChange.bodyAnalysis.dependency.domains,
            [.body, .profile, .review]
        )
    }
}
