import XCTest
@testable import FitAI

final class OnboardingRoutingTests: XCTestCase {
    func testExistingAccountIsNotSentToOnboardingWhenHydrationFails() {
        XCTAssertFalse(
            OnboardingRouting.shouldShowOnboarding(
                isAuthenticated: true,
                onboardingRequired: true,
                isNewUser: false,
                hydrationSucceeded: false,
                profileOnboarded: false
            )
        )
    }

    func testNewAccountStillGetsOnboardingWhenHydrationFails() {
        XCTAssertTrue(
            OnboardingRouting.shouldShowOnboarding(
                isAuthenticated: true,
                onboardingRequired: true,
                isNewUser: true,
                hydrationSucceeded: false,
                profileOnboarded: false
            )
        )
    }

    func testHydratedExistingProfileShowsTheApp() {
        XCTAssertFalse(
            OnboardingRouting.shouldShowOnboarding(
                isAuthenticated: true,
                onboardingRequired: true,
                isNewUser: false,
                hydrationSucceeded: true,
                profileOnboarded: true
            )
        )
    }

    func testHydratedUnonboardedProfileShowsOnboarding() {
        XCTAssertTrue(
            OnboardingRouting.shouldShowOnboarding(
                isAuthenticated: true,
                onboardingRequired: true,
                isNewUser: false,
                hydrationSucceeded: true,
                profileOnboarded: false
            )
        )
    }

    func testLoggedOutUserNeverSeesOnboarding() {
        XCTAssertFalse(
            OnboardingRouting.shouldShowOnboarding(
                isAuthenticated: false,
                onboardingRequired: true,
                isNewUser: true,
                hydrationSucceeded: true,
                profileOnboarded: false
            )
        )
    }
}
