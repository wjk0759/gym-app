import XCTest
@testable import FitAI

final class BodyMetricSeedPolicyTests: XCTestCase {
    func testHydratedOnboardedProfileWithoutMetricsCanSeedBaseline() {
        XCTAssertTrue(
            AppStore.BodyMetricSeedPolicy.shouldSeedAfterHydration(
                isOnboarded: true,
                hasServerBodyValues: true,
                hasLocalMetrics: false
            )
        )
    }

    func testUnonboardedOrUnhydratedProfileDoesNotSeed() {
        XCTAssertFalse(
            AppStore.BodyMetricSeedPolicy.shouldSeedAfterHydration(
                isOnboarded: false,
                hasServerBodyValues: true,
                hasLocalMetrics: false
            )
        )
        XCTAssertFalse(
            AppStore.BodyMetricSeedPolicy.shouldSeedAfterHydration(
                isOnboarded: true,
                hasServerBodyValues: false,
                hasLocalMetrics: false
            )
        )
    }

    func testExistingLocalMetricsAreNeverReplaced() {
        XCTAssertFalse(
            AppStore.BodyMetricSeedPolicy.shouldSeedAfterHydration(
                isOnboarded: true,
                hasServerBodyValues: true,
                hasLocalMetrics: true
            )
        )
    }
}
