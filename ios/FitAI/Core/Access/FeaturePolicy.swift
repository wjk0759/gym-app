import Foundation

/// Pure access decisions derived from the server snapshot plus the StoreKit
/// fallback. Views and services ask this type instead of re-implementing Pro
/// checks, so a new paywall entry cannot drift from the server rules.
struct FeaturePolicy: Equatable {
    let snapshot: AccessSnapshot?
    let storeKitPro: Bool
    let debugForcePro: Bool

    var isPro: Bool {
        snapshot?.isPro == true || storeKitPro || debugForcePro
    }

    /// Pro is a single global entitlement, not a per-feature subscription.
    func hasAccess(to _: ProFeature) -> Bool {
        isPro
    }

    var canGenerateTrainingPlan: Bool {
        isPro
    }

    /// The onboarding plan is the account's one free training-plan trial.
    var canGenerateOnboardingPlan: Bool {
        isPro || snapshot?.trainingPlan?.trialUsed != true
    }

    var canGenerateMealPlan: Bool {
        isPro || snapshot?.mealPlanTrialAvailable == true
    }

    var canSendCoachMessage: Bool {
        if isPro { return true }
        guard let coach = snapshot?.coachAI else { return true }
        return coach.canSend ?? true
    }

    var coachRemaining: Int? {
        isPro ? nil : snapshot?.coachRemaining
    }
}
