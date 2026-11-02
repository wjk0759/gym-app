import SwiftUI

extension CoachOnboardingView {
    // MARK: - Report

    var reportStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorialHeader(
                eyebrow: "起点报告",
                title: "先把起点看清楚",
                subtitle: "这不是体检，是接下来 4 周的训练依据。"
            )

            reportIdentityCard
            reportMetricsCard
            reportRecommendationCard
            reportActionCard

            Text("数据只用于生成训练和饮食建议；伤病与疼痛会被安全规则拦截。")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .padding(.bottom, 6)
        }
    }

    var reportIdentityCard: some View {
        HStack(alignment: .center, spacing: 16) {
            if let bodyType {
                BodySilhouette(
                    type: bodyType,
                    sex: draft.sex,
                    fill: Theme.cobalt.opacity(0.12),
                    stroke: Theme.cobalt,
                    lineWidth: 1.2
                )
                .frame(width: 78, height: 150)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.nickname.isEmpty ? "你的起点" : draft.nickname)
                    .font(AppType.title)
                    .foregroundStyle(Theme.ink)
                Text("\(draft.age) 岁 · \(draft.sex.label) · \(String(format: "%.0f", draft.heightCM)) cm · \(String(format: "%.1f", draft.weightKG)) kg")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                if let bodyType {
                    Text("\(bodyType.label) · \(bodyType.detail)")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
                Text("\(draft.weeklyDays) 练/周 · \(draft.sessionMinutes) 分钟/次")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    var reportMetricsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("身体数据")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("估算")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }

            HStack(spacing: 8) {
                EditorialMetric(title: "基础代谢", value: "\(bmr)", unit: "kcal", accent: Theme.cobalt)
                EditorialMetric(title: "BMI", value: String(format: "%.1f", draft.bmi), accent: Theme.lime)
                EditorialMetric(title: "体脂", value: String(format: "%.0f", draft.bodyFatPCT), unit: "%", accent: Theme.coral)
            }

            VStack(spacing: 8) {
                gaugeRow(
                    title: "体脂",
                    value: String(format: "%.0f%%", draft.bodyFatPCT),
                    progress: min(1, draft.bodyFatPCT / 45),
                    color: Theme.coral,
                    left: "偏低",
                    right: "偏高"
                )
                gaugeRow(
                    title: "BMI",
                    value: String(format: "%.1f", draft.bmi),
                    progress: min(1, draft.bmi / 35),
                    color: Theme.cobalt,
                    left: "偏低",
                    right: "偏高"
                )
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    var reportRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RecommendationBadge(
                    text: draft.goalType == recommendedGoal
                        ? "和你的选择一致"
                        : "教练建议 \(recommendedGoal.label)"
                )
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(draft.goalType.label)
                    .font(AppType.hero)
                    .foregroundStyle(Theme.ink)
                Text("你选的主目标")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(draft.goalType.detail)
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)

            InkDivider()

            HStack(spacing: 8) {
                EditorialMetric(title: "每周", value: "\(draft.weeklyDays)", unit: "次")
                EditorialMetric(title: "每次", value: "\(draft.sessionMinutes)", unit: "分钟")
                EditorialMetric(
                    title: "热量",
                    value: "\(DietPlanner.targets(profile: draft).kcal)",
                    unit: "kcal"
                )
            }
        }
        .padding(16)
        .background(Theme.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
        }
    }

    var reportActionCard: some View {
        let focusText = focusAreas.isEmpty ? "全身均衡" : focusAreas.map(\.label).joined(separator: "、")
        let equipmentText = draft.equipment.map(\.label).sorted().joined(separator: "、")
        let safetyText = injuries
            .union(injuryNote.isEmpty ? [String]() : [injuryNote])
            .filter { !$0.isEmpty }
            .joined(separator: "、")

        return VStack(alignment: .leading, spacing: 10) {
            Text("我会先这样安排")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            if let bodyType {
                actionLine("训练重点：\(focusText)，计划会优先安排")
                actionLine("体型参考：\(bodyType.label)，报告会记录这个重点")
            } else {
                actionLine("训练重点：\(focusText)")
            }
            actionLine("器械：\(equipmentText)")
            if !safetyText.isEmpty {
                actionLine("安全限制：\(safetyText)")
            }
            actionLine("计划会在生成后进入 Today，你可以随时找教练改。")
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
