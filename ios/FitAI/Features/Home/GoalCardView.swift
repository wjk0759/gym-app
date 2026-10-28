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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(goal.distanceText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("目标日期 \(goal.targetDateText) · \(goal.dateStatus)")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Text("\(goal.progress)%")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text("完成")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            ProgressView(value: Double(goal.progress) / 100)
                .tint(Theme.accent)

            HStack {
                Text("起始 \(GoalProgress.format(goal.startWeight))")
                Spacer()
                Text("当前 \(GoalProgress.format(goal.currentWeight))")
                Spacer()
                Text("目标 \(goal.targetWeight > 0 ? GoalProgress.format(goal.targetWeight) : "—")")
            }
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)

            if !goal.targetSummary.isEmpty {
                Text(goal.targetSummary)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Text(goal.hasTodayMetric ? "今日已打卡 · 进度已更新" : "今天记录一次，进度自动更新")
                    .font(.caption2)
                    .foregroundStyle(goal.hasTodayMetric ? Theme.accent : Theme.tertiaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button("记录今日数据", action: onCheckIn)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.accent.opacity(0.10), in: Capsule())
            }
        }
        .glassCard()
    }
}
