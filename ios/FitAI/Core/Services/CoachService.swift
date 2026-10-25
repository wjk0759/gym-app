import Foundation

enum CoachService {
    private static let safetyRules: [([String], String)] = [
        (
            ["胸痛", "胸闷", "呼吸困难", "喘不上气", "晕厥", "昏倒"],
            "你描述的可能是需要立即处理的情况。请马上停止训练，坐下休息；如果症状持续或加重，请立即就医或拨打 120。我可以帮你把今天的训练改成休息，但不要继续做任何高强度动作。"
        ),
        (
            ["剧痛", "刺痛", "肿胀", "麻木", "无法承重", "骨折", "扭伤"],
            "关节剧痛、肿胀或麻木不适合继续训练。请先停止相关动作，冰敷并尽快找医生或康复师评估。在明确诊断前，我不会给你继续加练的建议。"
        ),
        (
            ["怀孕", "孕期", "产后", "术后", "手术"],
            "孕期、产后恢复期和术后训练需要专业评估。建议先咨询产科医生或康复师，再决定训练内容。我可以帮你记录当前状态，但不提供这类训练处方。"
        ),
        (
            ["厌食", "暴食", "催吐", "绝食"],
            "你提到的饮食状态需要专业支持。建议联系营养科或心理医生；我不会给你极端热量或断食方案。"
        )
    ]

    static func reply(
        to message: String,
        profile: UserProfile,
        plan: TrainingPlan?,
        skill: CoachSkill = .trainer
    ) -> ChatMessage {
        for (keywords, text) in safetyRules
        where keywords.contains(where: { message.contains($0) }) {
            return ChatMessage(role: .assistant, text: text, isSafety: true)
        }

        if message.contains("今天练") || message.contains("练什么") || message.contains("计划") {
            if let day = plan?.firstWeek.first(where: { $0.weekday == Weekday.today }) {
                var lines = ["今天建议练「\(day.title)」，共 \(day.exercises.count) 个动作："]
                for item in day.exercises {
                    lines.append("· \(item.displayName) \(item.sets) 组 × \(item.reps)，休息 \(item.restSec)s")
                }
                lines.append("如果状态一般，把最后一组去掉，优先保证动作质量。")
                return ChatMessage(role: .assistant, text: lines.joined(separator: "\n"))
            }
            if let day = plan?.firstWeek.first {
                let names = day.exercises.map(\.displayName).joined(separator: "、")
                return ChatMessage(
                    role: .assistant,
                    text: "今天是休息日。下一次训练是「\(day.title)」：\(names)。可以散步或做 10 分钟拉伸。"
                )
            }
            return ChatMessage(
                role: .assistant,
                text: "你还没有生成计划。先在「计划」页生成一份，我再按你的器械和时间帮你安排。"
            )
        }

        if message.contains("替代") || message.contains("没有器械") || message.contains("换动作") {
            var muscle: MuscleGroup = .chest
            let mapping: [(String, MuscleGroup)] = [
                ("胸", .chest), ("背", .back), ("腿", .legs), ("臀", .glutes),
                ("肩", .shoulders), ("手臂", .arms), ("核心", .core), ("腹", .core)
            ]
            for (keyword, group) in mapping where message.contains(keyword) {
                muscle = group
                break
            }
            let candidates = ExerciseLibrary
                .candidates(muscle: muscle, equipment: profile.availableEquipment)
                .prefix(4)
            if candidates.isEmpty {
                return ChatMessage(role: .assistant, text: "你的器械清单里暂时没有这个肌群的动作，可以到「我的」里补充器械。")
            }
            var lines = ["可以试试这些\(muscle.label)部替代动作："]
            for item in candidates {
                lines.append("· \(item.nameZH)（\(item.equipment.label)）")
            }
            lines.append("选择能稳定完成 8–12 次的重量，动作变形就降重量。")
            return ChatMessage(role: .assistant, text: lines.joined(separator: "\n"))
        }

        if message.contains("吃") || message.contains("蛋白") || message.contains("热量") || message.contains("饮食") {
            let protein = Int((profile.weightKG * 1.8).rounded())
            return ChatMessage(
                role: .assistant,
                text: "按你的体重，每天蛋白质建议在 \(protein)g 左右，分 3–4 餐摄入；训练后 1–2 小时内吃到 20–30g 蛋白质即可。如果目标是减脂，先保证蛋白质和蔬菜，再控制主食分量。疾病相关饮食请咨询营养科医生。"
            )
        }

        if message.contains("酸") || message.contains("疼") || message.contains("痛") {
            return ChatMessage(
                role: .assistant,
                text: "训练后的延迟性酸痛通常 24–72 小时缓解，可以低强度活动、拉伸、保证睡眠。如果是关节刺痛、肿胀或影响走路，先停止训练并找医生评估。"
            )
        }

        if skill == .nutrition {
            let protein = Int((profile.weightKG * 1.8).rounded())
            return ChatMessage(
                role: .assistant,
                text: "营养师模式下，我先给一个保守区间：每天蛋白质约 \(protein)g，分 3–4 餐摄入；每餐先安排蛋白质和蔬菜，再根据训练量调整主食。如果有糖尿病、肾病、孕期或进食障碍，请先咨询医生或注册营养师。"
            )
        }

        if skill == .rehab {
            return ChatMessage(
                role: .assistant,
                text: "康复师模式下，我不会在未评估的情况下给你诊断或加练。请先告诉我疼痛位置、持续多久、疼痛 0–10 分，以及是否有肿胀、麻木或无力。如果有明显肿胀、无法承重或神经症状，请先线下就医。"
            )
        }

        if let plan {
            return ChatMessage(
                role: .assistant,
                text: "我记住了。你可以具体问：今天练什么、某个动作怎么替代，或者把训练感受告诉我。当前计划「\(plan.title)」已记录，下次调整会参考你的完成率。"
            )
        }

        return ChatMessage(
            role: .assistant,
            text: "先完成建档并生成计划，我就能结合你的器械、目标和历史记录给出更具体的建议。"
        )
    }
}
