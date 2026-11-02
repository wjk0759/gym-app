import SwiftUI

extension HomeV2View {
    // MARK: - Missed and more

    var missedPlanCard: some View {
        let missed = store.missedPlanDays
        return Group {
            if let first = missed.first,
               let plan = store.plan,
               let date = plan.scheduledDate(for: first) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("有 \(missed.count) 次没完成")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(FitnessDate.short(date))
                            .font(AppType.micro)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    HStack(spacing: 14) {
                        Button("顺延这次") { store.deferPlanDay(first) }
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .buttonStyle(SubtlePressStyle())
                        Button("跳过这次") { store.skipPlanDay(first) }
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.tertiaryText)
                            .buttonStyle(SubtlePressStyle())
                        Spacer()
                    }
                }
                .padding(14)
                .background(Theme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.coral.opacity(0.28), lineWidth: 1)
                }
            }
        }
    }

    var moreSection: some View {
        DisclosureGroup {
            VStack(spacing: 12) {
                weeklySummaryCard
                GoalCardView {
                    bodyCheckInManual = true
                    showBodyCheckIn = true
                }
                aiReviewCard
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("目标、周报和更多")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .tint(Theme.cobalt)
    }

    var weeklySummaryCard: some View {
        let completion = store.weeklyCompletion
        let completed = store.currentWeekCompletedCount
        let planned = store.currentWeekPlannedCount
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本周完成")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(planned == 0 ? "本周全休" : "\(completed)/\(planned) 次")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            ProgressView(value: completion)
                .tint(Theme.cobalt)
            HStack(spacing: 8) {
                EditorialMetric(title: "累计训练", value: "\(store.sessions.count)", unit: "次")
                EditorialMetric(title: "总容量", value: "\(Int(store.totalVolume))", unit: "kg")
                EditorialMetric(title: "本周", value: "\(store.currentWeekSessions.count)", unit: "次")
            }
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    var aiReviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI 复盘")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("刷新") {
                    store.refreshWeeklyReview(force: true)
                }
                .font(AppType.micro)
                .foregroundStyle(Theme.cobalt)
                .buttonStyle(SubtlePressStyle())
                .disabled(store.isReviewingWeekly)
            }
            if let review = store.weeklyReview {
                Text(review.summary)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = review.actions.first {
                    Text("下一步：\(action)")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
            } else if store.isReviewingWeekly {
                Text("教练正在读本周训练…")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("完成一次训练后，这里会出现周复盘。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Button {
                store.requestPlanAdjustment()
            } label: {
                Label("和教练聊聊，再调整计划", systemImage: "bubble.left.and.bubble.right")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
