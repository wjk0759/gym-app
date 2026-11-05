import Foundation

/// Pure access decisions derived from the server snapshot. StoreKit is only a
/// purchase signal that triggers server sync; it must never unlock features by
/// itself. Views and services ask this type instead of re-implementing Pro
/// checks, so a new paywall entry cannot drift from the server rules.
struct FeaturePolicy: Equatable {
    let snapshot: AccessSnapshot?

    var isPro: Bool {
        snapshot?.isPro == true
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

    var coachLimit: Int? {
        isPro ? nil : snapshot?.coachAI?.weeklyLimit
    }
}
