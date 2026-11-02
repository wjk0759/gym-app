import SwiftUI

extension PlanHomeView {
    // MARK: - Plan

    func planSummaryCard(_ plan: TrainingPlan) -> some View {
        let completed = store.currentWeekSessions.count
        let planned = max(1, store.currentWeekPlannedCount)
        let progress = min(1, Double(completed) / Double(planned))

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("PLAN / 当前计划")
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Text("v\(plan.version)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(plan.title)
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(plan.weeks) 周 · \(plan.days.count) 个训练日")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            VStack(spacing: 5) {
                HStack {
                    Text("本周")
                    Spacer()
                    Text("\(store.currentWeekCompletedCount)/\(max(0, store.currentWeekPlannedCount)) 次")
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .monospacedDigit()

                ProgressView(value: progress)
                    .tint(Theme.cobalt)
            }

            Button {
                store.requestPlanAdjustment()
            } label: {
                Label("和教练聊聊，再调整计划", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }
}
