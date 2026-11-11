import Foundation

/// Owns plan generation mechanics so AppStore stays a state container.
///
/// The service deliberately returns a plan instead of mutating AppStore:
/// versioning, archiving, toasts, trial consumption and notifications remain
/// in the store's orchestration path.
struct PlanGenerationService {
    var client: APIClient = .shared

    func generateRemote(
        profile: UserProfile,
        strictEquipment: Bool,
        focusAreas: Set<BodyFocusArea>,
        force: Bool,
        onboarding: Bool,
        idempotencyKey: String
    ) async throws -> TrainingPlan {
        async let profileSync = client.syncProfile(profile)
        async let goalSync = client.syncGoal(profile)
        try await profileSync
        _ = try? await goalSync
        return try await client.generatePlan(
            force: force,
            onboarding: onboarding,
            strictEquipment: strictEquipment,
            split: profile.split,
            focus: BodyFocusArea.displayOrder
                .filter(focusAreas.contains)
                .map(\.rawValue),
            idempotencyKey: idempotencyKey
        )
    }

    func generateLocal(
        profile: UserProfile,
        dislikedSlugs: Set<String>,
        equipmentSlugs: [String],
        strictEquipment: Bool,
        weeklyWeekdays: [Int]?,
        focusAreas: Set<BodyFocusArea>,
        sessions: [WorkoutSession],
        planWeights: [String: Double]
    ) -> TrainingPlan {
        PlanGenerator.generate(
            profile: profile,
            dislikedSlugs: dislikedSlugs,
            equipmentSlugs: equipmentSlugs,
            strictEquipment: strictEquipment,
            weeklyWeekdays: weeklyWeekdays,
            focusAreas: focusAreas,
            sessions: sessions,
            planWeights: planWeights
        )
    }
}
