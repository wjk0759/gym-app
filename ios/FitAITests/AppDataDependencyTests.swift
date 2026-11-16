import XCTest

@testable import FitAI

final class AppDataDependencyTests: XCTestCase {
    func testBodyMetricInvalidatesTargetsAndReview() {
        let dependency = AppDataChange.bodyMetric.dependency

        XCTAssertEqual(
            dependency.domains,
            Set([.body, .profile, .diet, .review])
        )
        XCTAssertTrue(dependency.invalidatesTargets)
        XCTAssertFalse(dependency.reschedulesNotifications)
    }

    func testProfileChangeRefreshesBodyDietAndReview() {
        let dependency = AppDataChange.profile.dependency

        XCTAssertEqual(
            dependency.domains,
            Set([.profile, .body, .diet, .review])
        )
        XCTAssertTrue(dependency.invalidatesTargets)
    }

    func testFoodAndWorkoutUpdatesRefreshReview() {
        XCTAssertEqual(
            AppDataChange.foodLog.dependency.domains,
            Set([.diet, .review])
        )
        XCTAssertEqual(
            AppDataChange.workout.dependency.domains,
            Set([.workouts, .plan, .schedule, .review])
        )
    }

    func testPlanChangeInvalidatesTargetsAndReschedulesNotifications() {
        let dependency = AppDataChange.plan.dependency

        XCTAssertEqual(
            dependency.domains,
            Set([.plan, .schedule, .diet, .workouts, .review])
        )
        XCTAssertTrue(dependency.invalidatesTargets)
        XCTAssertTrue(dependency.reschedulesNotifications)
    }

    func testEquipmentAndBodyAnalysisStaySeparate() {
        XCTAssertEqual(
            AppDataChange.equipment.dependency.domains,
            Set([.equipment, .plan])
        )
        XCTAssertEqual(
            AppDataChange.bodyAnalysis.dependency.domains,
            Set([.body, .profile, .review])
        )
    }
}
