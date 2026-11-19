import SwiftUI

extension PlanHomeView {
    // MARK: - Equipment replan

    @ViewBuilder
    var equipmentReplanBanner: some View {
        if let issue = store.planEquipmentIssue,
           store.dismissedEquipmentReplanSignature != issue.signature {
            equipmentReplanCard(issue)
        }
    }

    func equipmentReplanCard(_ issue: PlanEquipmentIssue) -> some View {
        let examples = issue.unavailableSlugs
            .prefix(2)
            .compactMap { ExerciseLibrary.exercise(slug: $0)?.nameZH }
        let exampleText = examples.isEmpty
            ? "。"
            : "，比如\(examples.joined(separator: "、"))。"
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("器械变化")
                        .font(AppType.overline)
                        .tracking(1.2)
                        .foregroundStyle(Theme.cobalt)
                    Text("当前计划需要重排")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("有 \(issue.count) 个动作不在可用器械范围内\(exampleText)")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    store.dismissEquipmentReplanPrompt()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("暂不重排")
            }

            HStack(spacing: 8) {
                Button("重新生成计划") {
                    showRegenerate = true
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("暂不重排") {
                    store.dismissEquipmentReplanPrompt()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    // MARK: - Plan

    func planSummaryCard(_ plan: TrainingPlan) -> some View {
        let completed = store.currentWeekSessions.count
        let planned = max(1, store.currentWeekPlannedCount)
        let progress = min(1, Double(completed) / Double(planned))

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("当前计划")
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
