import Foundation

/// Pure routing decision for the login/onboarding boundary.
///
/// An existing account must never be sent into onboarding just because its
/// local profile file is empty on a fresh install. The server's
/// `onboarding_required` flag is authoritative; `/me` hydration can further
/// prove that a profile already exists. If hydration fails, only a brand-new
/// account is allowed into onboarding.
enum OnboardingRouting {
    static func shouldShowOnboarding(
        isAuthenticated: Bool,
        onboardingRequired: Bool,
        isNewUser: Bool,
        hydrationSucceeded: Bool,
        profileOnboarded: Bool
    ) -> Bool {
        guard isAuthenticated, onboardingRequired, !profileOnboarded else {
            return false
        }
        return isNewUser || hydrationSucceeded
    }
}
