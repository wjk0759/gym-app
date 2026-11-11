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
        skill: CoachSkill = .trainer,
        period: PeriodDay? = nil
    ) -> ChatMessage {
        for (keywords, text) in safetyRules
        where keywords.contains(where: { message.contains($0) }) {
            return ChatMessage(role: .assistant, text: text, isSafety: true)
        }

        if message.contains("今天练") || message.contains("练什么") || message.contains("计划") {
            if let day = plan?.day(on: Date()) {
                if period?.mode == .rest {
                    return ChatMessage(
                        role: .assistant,
                        text: "今天是经期休息日，原计划「\(day.title)」保留但不要求力量训练。优先补铁、蛋白质和睡眠；如果腹痛明显，只做散步或舒缓拉伸。"
                    )
                }
                var lines = [
                    period == nil
                        ? "今天建议练「\(day.title)」，共 \(day.exercises.count) 个动作："
                        : "今天是经期第 \(period?.day ?? 1) 天，建议做轻量版「\(day.title)」："
                ]
                for item in day.exercises {
                    let sets = period == nil ? item.sets : max(2, item.sets - 1)
                    let weightText = period == nil ? "" : "（负重约 80%）"
                    lines.append("· \(item.displayName) \(sets) 组 × \(item.reps)\(weightText)，休息 \(item.restSec)s")
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
                text: "还没生成计划，正常。先去「计划」页生成一份，"
                    + "我拿到你的器械和时间后，帮你把第一周排顺。"
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
                return ChatMessage(
                    role: .assistant,
                    text: "你的器械清单里暂时没有这个肌群的动作。"
                        + "去「我的」补两件常用器械，或者拍张照，我帮你认。"
                )
            }
            var lines = ["可以，先换动作，不用硬等。给你几个\(muscle.label)部替代："]
            for item in candidates {
                lines.append("· \(item.nameZH)（\(item.equipment.label)）")
            }
            lines.append("选一个能稳定做 8–12 次的重量，动作变形就降。要我现在帮你换进今天训练吗？")
            return ChatMessage(role: .assistant, text: lines.joined(separator: "\n"))
        }

        if message.contains("吃") || message.contains("蛋白") || message.contains("热量") || message.contains("饮食") {
            let protein = Int((profile.weightKG * 1.8).rounded())
            return ChatMessage(
                role: .assistant,
                text: "按你的体重，每天蛋白大约 \(protein)g，分 3–4 餐吃。"
                    + "每餐先放一掌心蛋白：鸡胸 100g、鱼 100g、虾 100g、牛肉 100g，"
                    + "或者鸡蛋 2 个加一杯牛奶。今天差多少？告诉我，我给你补法。"
                    + "有肾病、糖尿病或孕期，先问医生。"
            )
        }

        if message.contains("酸") || message.contains("疼") || message.contains("痛") {
            return ChatMessage(
                role: .assistant,
                text: "练完一两天酸，正常。今天可以散步、拉伸、早点睡；"
                    + "但如果是关节刺痛、麻木、肿胀，或者疼到影响走路，"
                    + "先停训练，尽快找医生看一下。"
            )
        }

        if skill == .nutrition {
            let protein = Int((profile.weightKG * 1.8).rounded())
            return ChatMessage(
                role: .assistant,
                text: "先给你一个保守范围：每天蛋白约 \(protein)g，分 3–4 餐吃。"
                    + "每餐一掌心蛋白加两拳蔬菜，主食按训练量调。"
                    + "有糖尿病、肾病、孕期或进食障碍，先问医生或注册营养师。"
            )
        }

        if skill == .rehab {
            return ChatMessage(
                role: .assistant,
                text: "我先不给你诊断。告诉我疼在哪、多久了、0–10 分有多疼，"
                    + "有没有肿胀、麻木或无力。"
                    + "要是有明显肿胀、无法承重或神经症状，先线下就医，别硬练。"
            )
        }

        if let plan {
            return ChatMessage(
                role: .assistant,
                text: "我在。你可以直接问：今天练什么、这个动作怎么换、蛋白还差多少怎么补。"
                    + "当前计划「\(plan.title)」我记着，下次调整会看你的完成率。"
            )
        }

        return ChatMessage(
            role: .assistant,
            text: "先把建档和计划补上，我就能结合你的器械、目标和历史，给你更具体的安排。"
        )
    }
}
