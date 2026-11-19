import SwiftUI

extension HomeV2View {
    var missedPlanCard: some View {
        let missed = store.missedPlanDays
        return Group {
            if let first = missed.first,
               let plan = store.plan,
               let date = plan.scheduledDate(for: first) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(missed.count) 次未完成")
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                        Text(FitnessDate.short(date))
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Button("顺延") { store.deferPlanDay(first) }
                    Button("跳过") { store.skipPlanDay(first) }
                }
                .buttonStyle(.plain)
                .font(AppType.caption)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}
