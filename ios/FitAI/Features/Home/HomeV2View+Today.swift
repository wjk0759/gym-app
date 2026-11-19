import SwiftUI

extension HomeV2View {
    // MARK: - Today

    @ViewBuilder
    var todaySection: some View {
        if store.isGenerating {
            generatingCard
        } else if let plan = store.plan {
            if let day = selectedDay {
                trainingCard(plan: plan, day: day)
            } else {
                restCard(plan: plan, period: store.todayPeriod)
            }
        } else {
            noPlanCard
        }
    }

    var generatingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("正在生成计划")
                    .font(AppType.hero)
                    .foregroundStyle(Theme.ink)
                Spacer()
                ProgressView().tint(Theme.cobalt)
            }
        }
        .editorialCard(accent: Theme.lime)
    }

    func trainingCard(plan: TrainingPlan, day: PlanDay) -> some View {
        let draft = store.draft(for: day.id)
        let completed = store.isPlanDayCompleted(day)
        let inProgress = draft != nil && !completed
        let completedSets = store.completedSets(for: day)
        let plannedSets = store.plannedSets(for: day)
        let progress = store.planDayProgress(day)
        let isToday = Calendar.current.isDateInToday(selectedDate)

        return VStack(alignment: .leading, spacing: 14) {
            Text(day.title)
                .font(AppType.hero)
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(day.focusText)
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)

            if let period = store.periodDay(for: day.date ?? selectedDate) {
                Text(period.mode == .rest
                     ? "经期休息"
                     : "经期第 \(period.day) 天 · 轻量")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cycle)
            }

            if completed || inProgress {
                VStack(spacing: 6) {
                    HStack {
                        Text(completed ? "已完成 \(plannedSets) 组" : "已练 \(completedSets)/\(plannedSets) 组")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
                    ProgressView(value: progress)
                        .tint(completed ? Theme.cobalt : Theme.lime)
                }
            }

            HStack(spacing: 8) {
                EditorialMetric(title: "动作", value: "\(day.exercises.count)", unit: "个")
                EditorialMetric(title: "预计", value: "\(day.estimatedMinutes)", unit: "分钟")
                EditorialMetric(
                    title: "状态",
                    value: completed ? "完成" : (inProgress ? "进行" : "待练")
                )
            }

            VStack(spacing: 7) {
                ForEach(day.exercises.prefix(3)) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(completed ? Theme.cobalt : Theme.lime)
                            .frame(width: 6, height: 6)
                        Text(item.displayName)
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(item.targetText)
                            .font(AppType.micro)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if day.exercises.count > 3 {
                    Text("还有 \(day.exercises.count - 3) 个动作")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if completed {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.cobalt)
                    Text("今天已完成")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(11)
                .background(Theme.cobalt.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if isToday {
                Button(inProgress ? "继续训练" : "开始训练") {
                    if inProgress {
                        workoutDay = day
                    } else {
                        showCompose = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 14) {
                    Button("今天没空 / 改天") {
                        showTodayUnavailable = true
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .buttonStyle(SubtlePressStyle())

                    Button("调整日期") {
                        showSchedule = true
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .buttonStyle(SubtlePressStyle())

                    Spacer()
                }
            } else {
                Button("查看这一天的计划") {
                    store.openRecord(for: selectedDate)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .editorialCard(accent: completed ? Theme.cobalt : Theme.lime)
    }

    var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.deferredPlanPreview == nil ? "还没有训练计划" : "计划还等你确认")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            if store.deferredPlanPreview != nil {
                Button("继续确认计划") {
                    store.resumeDeferredPlan()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("重新生成") {
                    store.discardPendingPlan()
                    store.generatePlan(onboarding: true)
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("生成计划") {
                    store.generatePlan()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .editorialCard(accent: Theme.lime)
    }

    func restCard(plan: TrainingPlan, period: PeriodDay?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(period?.mode == .rest ? "经期休息日" : "今天休息")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Button("看本周安排") {
                showSchedule = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .editorialCard(accent: Theme.cobalt)
    }
}
