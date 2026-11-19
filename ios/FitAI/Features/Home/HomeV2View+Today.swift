import SwiftUI

extension HomeV2View {
    @ViewBuilder
    var todaySection: some View {
        if store.isGenerating {
            generatingCard
        } else if store.plan != nil {
            if let day = selectedDay {
                trainingCard(day: day)
            } else {
                restCard(period: store.todayPeriod)
            }
        } else {
            noPlanCard
        }
    }

    var generatingCard: some View {
        HStack(spacing: 12) {
            Text("正在生成计划")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            ProgressView()
        }
        .card()
    }

    func trainingCard(day: PlanDay) -> some View {
        let draft = store.draft(for: day.id)
        let completed = store.isPlanDayCompleted(day)
        let inProgress = draft != nil && !completed
        let progress = store.planDayProgress(day)
        let isToday = Calendar.current.isDateInToday(selectedDate)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.title)
                    .font(AppType.hero)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.secondaryText)
                        .accessibilityLabel("已完成")
                }
            }

            Text("\(day.exercises.count) 个动作 · \(day.estimatedMinutes) 分钟")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            if let period = store.periodDay(for: day.date ?? selectedDate) {
                Text(period.mode == .rest ? "经期：休息" : "经期：减 1 组")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cycle)
            }

            if inProgress {
                ProgressView(value: progress)
                    .tint(Theme.primary)
            }

            ForEach(day.exercises.prefix(3)) { item in
                HStack(spacing: 8) {
                    Text(item.displayName)
                        .font(AppType.body)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.targetText)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if isToday && !completed {
                Button(inProgress ? "继续训练" : "开始训练") {
                    if inProgress {
                        workoutDay = day
                    } else {
                        showCompose = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 16) {
                    Button("改天") {
                        showTodayUnavailable = true
                    }
                    Button("调整日期") {
                        showSchedule = true
                    }
                    Spacer(minLength: 0)
                }
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .buttonStyle(.plain)
            } else if !completed {
                Button("查看计划") {
                    store.openRecord(for: selectedDate)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    var noPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("还没有训练计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    func restCard(period: PeriodDay?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(period?.mode == .rest ? "经期休息" : "今天休息")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
            Button("看本周安排") {
                showSchedule = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }
}
