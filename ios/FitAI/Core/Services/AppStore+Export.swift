import Foundation

/// 本机数据导出：把 profile/plan/sessions/chat/food/body 等状态编码为 JSON。
/// 只读快照，不删除或修改任何数据。
extension AppStore {
    func exportData() -> String {
        let payload = ExportPayload(
            exportedAt: Date(),
            profile: profile,
            plan: plan,
            planHistory: planHistory,
            sessions: sessions,
            chat: chat,
            foodLogs: foodLogs,
            customFoods: customFoods,
            dislikedSlugs: Array(dislikedSlugs).sorted(),
            healthKitEnabled: healthKitEnabled,
            bodyAnalyses: bodyAnalyses,
            equipmentLibrary: equipmentLibrary,
            bodyMetrics: bodyMetrics,
            bodyCheckInFrequency: bodyCheckInFrequency
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private struct ExportPayload: Codable {
        let exportedAt: Date
        let profile: UserProfile
        let plan: TrainingPlan?
        let planHistory: [TrainingPlan]
        let sessions: [WorkoutSession]
        let chat: [ChatMessage]
        let foodLogs: [FoodLog]
        let customFoods: [FoodItem]
        let dislikedSlugs: [String]
        let healthKitEnabled: Bool
        let bodyAnalyses: [BodyAnalysis]
        let equipmentLibrary: [EquipmentItem]
        let bodyMetrics: [BodyMetric]
        let bodyCheckInFrequency: BodyCheckInFrequency
    }
}
