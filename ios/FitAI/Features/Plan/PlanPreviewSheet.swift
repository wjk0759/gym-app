import SwiftUI

/// First-plan confirmation. The generated plan is not made active until the
/// user accepts it here, so onboarding can explain the plan before the first
/// training day instead of dropping the user into an opaque Today card.
struct PlanPreviewSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let plan: TrainingPlan

    private var firstWeek: [PlanDay] {
        plan.firstWeek
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    metrics
                    weekCard
                    footer
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("确认训练计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后") {
                        store.deferPendingPlan()
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PLAN / 第一版计划")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text(plan.title)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("先看看这四周怎么练，再决定是否开始。确认前不会覆盖你已有的训练。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            EditorialMetric(title: "周期", value: "\(plan.weeks)", unit: "周")
            EditorialMetric(
                title: "每周",
                value: "\(max(1, plan.weeklyDays ?? firstWeek.count))",
                unit: "练"
            )
            EditorialMetric(
                title: "单次",
                value: "\(max(1, firstWeek.first?.estimatedMinutes ?? store.profile.sessionMinutes))",
                unit: "分钟"
            )
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("第一周")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(plan.days.count) 个训练日")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if firstWeek.isEmpty {
                Text("第一周还没有训练日，可以重新生成。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(firstWeek) { day in
                    HStack(alignment: .top, spacing: 10) {
                        Text(FitnessDate.short(plan.scheduledDate(for: day) ?? Date()))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.cobalt)
                            .frame(width: 42, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(
                                day.exercises.prefix(3).map(\.displayName).joined(separator: " · ")
                                    + (day.exercises.count > 3 ? " · …" : "")
                            )
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 5)
                    if day.id != firstWeek.last?.id {
                        InkDivider()
                    }
                }
            }

            Text("计划由\(plan.generatedBy == "ai" ? " AI 结合你的档案" : "规则模板结合你的档案")生成，训练中仍可替换动作、调整重量。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button("开始这个计划") {
                Haptics.success()
                store.confirmPendingPlan()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 8) {
                Button("先调整") {
                    store.confirmPendingPlan(openRecord: true)
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("重新生成") {
                    store.discardPendingPlan()
                    store.generatePlan(onboarding: true)
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.top, 4)
    }
}
