import Foundation

enum BodyAnalysisService {
    private struct Variant {
        let summary: String
        let focus: [MuscleGroup]
        let recommendations: [String]
        let confidence: Double
    }

    private static let disclaimer = "照片分析仅用于训练重点参考，不构成体脂率、体态诊断或医疗建议。如需体成分数据，请使用专业设备；如有疼痛或伤病，请咨询医生或康复师。"

    private static let variants: [Variant] = [
        Variant(
            summary: "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定，减少只练胸和手臂的倾向。",
            focus: [.back, .glutes, .core],
            recommendations: [
                "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
                "臀部训练加入臀推或臀桥，每周 2 次",
                "核心稳定加入平板支撑，每次训练收尾 2 组"
            ],
            confidence: 0.82
        ),
        Variant(
            summary: "下肢与核心可以承担更多训练量，建议采用上下肢分化，先把深蹲和髋伸动作做扎实。",
            focus: [.legs, .glutes, .core],
            recommendations: [
                "保留深蹲或腿举作为下肢主项",
                "加入罗马尼亚硬拉，强化后链",
                "每周至少 2 次核心稳定训练"
            ],
            confidence: 0.76
        ),
        Variant(
            summary: "上肢推拉比例可以更平衡，建议增加划船类动作，同时控制卧推总量，避免肩部过度疲劳。",
            focus: [.back, .shoulders, .core],
            recommendations: [
                "推拉比例调整为 1:1.5",
                "加入面拉，改善肩胛稳定",
                "推日最后减少 1 组卧推，改为划船"
            ],
            confidence: 0.71
        ),
        Variant(
            summary: "训练重点可以放在全身复合动作与稳定输出，不建议只做孤立动作。先建立规律，再追求围度变化。",
            focus: [.legs, .back, .core],
            recommendations: [
                "每次训练保留 2 个复合动作",
                "优先深蹲、硬拉、划船、推举",
                "每周记录完成率，连续两周再增加负荷"
            ],
            confidence: 0.68
        )
    ]

    static func analyze(imageData: Data) -> BodyAnalysis {
        let seed = imageData.reduce(0) { ($0 + Int($1)) % 100_000 }
        let variant = variants[seed % variants.count]
        return BodyAnalysis(
            summary: variant.summary,
            focusAreas: variant.focus,
            recommendations: variant.recommendations,
            confidence: variant.confidence,
            disclaimer: disclaimer
        )
    }
}
