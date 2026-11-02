import XCTest
@testable import FitAI

final class FeaturePolicyTests: XCTestCase {
    private func snapshot(_ json: String) throws -> AccessSnapshot {
        try JSONDecoder().decode(AccessSnapshot.self, from: Data(json.utf8))
    }

    func testStoreKitFallbackUnlocksEveryProFeature() {
        let policy = FeaturePolicy(
            snapshot: nil,
            storeKitPro: true,
            debugForcePro: false
        )

        XCTAssertTrue(policy.isPro)
        XCTAssertTrue(policy.hasAccess(to: .mealPlan))
        XCTAssertTrue(policy.canGenerateTrainingPlan)
        XCTAssertTrue(policy.canGenerateMealPlan)
        XCTAssertTrue(policy.canSendCoachMessage)
        XCTAssertNil(policy.coachRemaining)
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
            FeaturePolicy(snapshot: available, storeKitPro: false, debugForcePro: false)
                .canGenerateMealPlan
        )
        XCTAssertFalse(
            FeaturePolicy(snapshot: used, storeKitPro: false, debugForcePro: false)
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
        let policy = FeaturePolicy(
            snapshot: snapshot,
            storeKitPro: false,
            debugForcePro: false
        )

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
        let policy = FeaturePolicy(
            snapshot: used,
            storeKitPro: false,
            debugForcePro: false
        )

        XCTAssertFalse(policy.canGenerateTrainingPlan)
        XCTAssertFalse(policy.canGenerateOnboardingPlan)
    }
}
