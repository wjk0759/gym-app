import Foundation

/// 计划生成的结果边界。
/// 远端路径只返回服务端计划；本地路径只返回模板计划。
/// 版本号、归档、试用消耗、toast 和通知仍由 AppStore 编排。
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
            preview: onboarding,
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
