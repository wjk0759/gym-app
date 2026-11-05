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
                Text("AI 正在编排")
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                ProgressView().tint(Theme.cobalt)
            }
            Text("4 周计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Text("正在匹配动作、分配训练日、校验器械与伤病限制。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                loadingPill("目标", done: true)
                loadingPill("器械", done: true)
                loadingPill("计划", done: false)
            }
        }
        .editorialCard(accent: Theme.lime)
    }

    func loadingPill(_ title: String, done: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: done ? "checkmark" : "circle.dotted")
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(AppType.micro)
        }
        .foregroundStyle(done ? Theme.ink : Theme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(done ? Theme.lime : Theme.surface, in: Capsule())
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
            HStack {
                Text(isToday ? "TODAY / 今天" : FitnessDate.short(selectedDate).uppercased())
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Text("第 \(store.currentPlanWeek) 周")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }

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
                     ? "经期已设为休息：今天不安排力量训练。"
                     : "经期第 \(period.day) 天：自动少 1 组，负重约 80%。")
                    .font(AppType.micro)
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
                    Text("今天已完成，记录已保存")
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
            Text("还没有训练计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Text("先让我按你的目标、器械和时间排一份 4 周计划。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .editorialCard(accent: Theme.lime)
    }

    func restCard(plan: TrainingPlan, period: PeriodDay?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(period?.mode == .rest ? "经期休息日" : "今天休息")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Text(
                period?.mode == .rest
                    ? "计划保留，但今天不要求力量训练。补铁、蛋白质和睡眠优先。"
                    : "恢复也是训练的一部分。睡够、吃够，下一次会更好。"
            )
            .font(AppType.body)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            Button("看本周安排") {
                showSchedule = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .editorialCard(accent: Theme.cobalt)
    }
}
