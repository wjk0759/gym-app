import XCTest
@testable import FitAI

final class FeaturePolicyTests: XCTestCase {
    private func snapshot(_ json: String) throws -> AccessSnapshot {
        try JSONDecoder().decode(AccessSnapshot.self, from: Data(json.utf8))
    }

    func testOnlyServerSnapshotUnlocksProFeatures() throws {
        let free = try snapshot(
            """
            {"is_pro":false,"pro_sources":[],"features":{}}
            """
        )
        let pro = try snapshot(
            """
            {"is_pro":true,"pro_sources":["admin"],"features":{}}
            """
        )

        XCTAssertFalse(FeaturePolicy(snapshot: free).isPro)
        XCTAssertFalse(FeaturePolicy(snapshot: nil).isPro)
        XCTAssertFalse(FeaturePolicy(snapshot: free).hasAccess(to: .equipmentScan))
        XCTAssertTrue(FeaturePolicy(snapshot: pro).isPro)
        XCTAssertTrue(FeaturePolicy(snapshot: pro).hasAccess(to: .mealPlan))
        XCTAssertTrue(FeaturePolicy(snapshot: pro).hasAccess(to: .equipmentScan))
    }

    func testFreeMealPlanOnlyAllowsTheSavedTrial() throws {
        let available = try snapshot(
            """
            {"is_pro":false,"pro_sources":[],"features":{
              "meal_plan":{"trial_available":true,"can_generate":true}
            }}
            """
        )
        let used = try snapshot(
            """
            {"is_pro":false,"pro_sources":[],"features":{
              "meal_plan":{"trial_available":false,"can_generate":false}
            }}
            """
        )

        XCTAssertTrue(
            FeaturePolicy(snapshot: available)
                .canGenerateMealPlan
        )
        XCTAssertFalse(
            FeaturePolicy(snapshot: used)
                .canGenerateMealPlan
        )
    }

    func testExhaustedCoachQuotaBlocksFreeUsers() throws {
        let snapshot = try snapshot(
            """
            {"is_pro":false,"pro_sources":[],"features":{
              "coach_ai":{"weekly_limit":3,"used":3,"remaining":0,"can_send":false}
            }}
            """
        )
        let policy = FeaturePolicy(snapshot: snapshot)

        XCTAssertFalse(policy.canSendCoachMessage)
        XCTAssertEqual(policy.coachRemaining, 0)
    }

    func testTrainingTrialIsOnboardingOnly() throws {
        let used = try snapshot(
            """
            {"is_pro":false,"pro_sources":[],"features":{
              "training_plan":{"trial_used":true,"can_generate":false}
            }}
            """
        )
        let policy = FeaturePolicy(snapshot: used)

        XCTAssertFalse(policy.canGenerateTrainingPlan)
        XCTAssertFalse(policy.canGenerateOnboardingPlan)
    }
}
