import SwiftUI

struct GoalCardView: View {
    @Environment(AppStore.self) private var store

    let onCheckIn: () -> Void

    var body: some View {
        let goal = store.goalProgress
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当前目标 · \(store.profile.goalType.label)")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                    Text(goal.distanceText)
                        .font(AppType.title)
                        .foregroundStyle(Theme.ink)
                    Text("目标日期 \(goal.targetDateText) · \(goal.dateStatus)")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Text("\(goal.progress)%")
                        .font(AppType.numberSmall)
                        .foregroundStyle(Theme.cobalt)
                    Text("完成")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Theme.cobalt.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ProgressView(value: Double(goal.progress) / 100)
                .tint(Theme.cobalt)

            HStack {
                Text("起始 \(GoalProgress.format(goal.startWeight))")
                Spacer()
                Text("当前 \(GoalProgress.format(goal.currentWeight))")
                Spacer()
                Text("目标 \(goal.targetWeight > 0 ? GoalProgress.format(goal.targetWeight) : "—")")
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)

            if !goal.targetSummary.isEmpty {
                Text(goal.targetSummary)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 4)
                Button("记录今日数据", action: onCheckIn)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.cobalt.opacity(0.10), in: Capsule())
            }
        }
        .card()
    }
}
