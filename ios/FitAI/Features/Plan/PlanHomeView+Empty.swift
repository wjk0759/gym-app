import SwiftUI

extension PlanHomeView {
    // MARK: - Empty and generating

    var generatingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 正在编排")
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                ProgressView()
                    .tint(Theme.cobalt)
            }

            Text("4 周计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)

            Text("正在匹配动作、分配训练日、校验器械与伤病限制。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: Theme.lime)
    }

    var emptyPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还没有训练计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)

            Text("先让我按你的目标、器械和时间排一份 4 周计划。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .editorialCard(accent: Theme.lime)
    }
}
