import SwiftUI

extension PlanHomeView {
    // MARK: - Selected day

    func selectedDayCard(plan: TrainingPlan?) -> some View {
        let daySessions = sessions(on: selectedDate)
        let plannedDay = planDay(on: selectedDate, plan: plan)
        let planCompleted = plannedDay.map { store.isPlanDayCompleted($0) } ?? false
        let inProgress = plannedDay.flatMap { store.draft(for: $0.id) } != nil && !planCompleted
        let period = store.periodDay(for: selectedDate)
        let status = dayStatus(
            planCompleted: planCompleted,
            inProgress: inProgress,
            planned: plannedDay != nil,
            hasSessions: !daySessions.isEmpty,
            period: period
        )

        return VStack(alignment: .leading, spacing: 12) {
            dayHeader(
                plannedDay: plannedDay,
                sessions: daySessions,
                period: period,
                status: status
            )

            if let plannedDay {
                dayPlanMeta(plannedDay)
                dayProgress(plannedDay: plannedDay, completed: planCompleted)
            } else if !daySessions.isEmpty {
                let minutes = daySessions.reduce(0) { $0 + $1.durationMinutes }
                let volume = daySessions.reduce(0) { $0 + $1.volume }
                Text("\(daySessions.count) 次 · \(minutes) 分钟 · \(Int(volume)) kg")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            periodBanner(period)

            if !daySessions.isEmpty {
                InkDivider()
                    .padding(.vertical, 2)
                daySessionList(daySessions)
            }

            if let plannedDay {
                InkDivider()
                    .padding(.vertical, 2)
                dayExerciseList(plannedDay, completed: planCompleted)
            }

            dayActions(
                plannedDay: plannedDay,
                plan: plan,
                planCompleted: planCompleted,
                inProgress: inProgress,
                sessions: daySessions,
                period: period
            )

            InkDivider()
                .padding(.vertical, 4)

            dayNutritionSection
        }
        .card()
    }

    func dayStatus(
        planCompleted: Bool,
        inProgress: Bool,
        planned: Bool,
        hasSessions: Bool,
        period: PeriodDay?
    ) -> DayStatus {
        if planCompleted {
            return DayStatus(text: "已完成")
        }
        if inProgress {
            return DayStatus(text: "进行中")
        }
        if planned {
            return DayStatus(text: "计划日")
        }
        if hasSessions {
            return DayStatus(text: "已记录")
        }
        if period?.mode == .rest {
            return DayStatus(text: "休息日")
        }
        return DayStatus(text: "休息日")
    }

    func dayHeader(
        plannedDay: PlanDay?,
        sessions: [WorkoutSession],
        period: PeriodDay?,
        status: DayStatus
    ) -> some View {
        let title = plannedDay?.title
            ?? sessions.first?.dayTitle
            ?? (period?.mode == .rest ? "经期休息" : "休息日")

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(dayEyebrow(selectedDate))
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)

                Spacer(minLength: 0)

                if plannedDay != nil || !sessions.isEmpty {
                    Text(status.text)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Text(title)
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func dayPlanMeta(_ day: PlanDay) -> some View {
        HStack(spacing: 8) {
            Text("\(day.exercises.count) 个动作 · \(day.estimatedMinutes) 分钟")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button {
                Haptics.tap()
                editingDay = day
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑计划")
        }
    }

    func dayProgress(plannedDay: PlanDay, completed: Bool) -> some View {
        let plannedSets = store.plannedSets(for: plannedDay)
        let doneSets = store.completedSets(for: plannedDay)
        let progress = store.planDayProgress(plannedDay)

        return Group {
            if plannedSets > 0, doneSets > 0 || completed {
                VStack(spacing: 5) {
                    HStack {
                        Text(completed ? "全部 \(plannedSets) 组已完成" : "已记录 \(doneSets)/\(plannedSets) 组")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .monospacedDigit()

                    ProgressView(value: progress)
                        .tint(completed ? Theme.cobalt : Theme.lime)
                }
            }
        }
    }

    @ViewBuilder
    func periodBanner(_ period: PeriodDay?) -> some View {
        if let period {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.cycle)
                    .padding(.top, 2)

                Text("经期第 \(period.day) 天 · \(period.mode.title)")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                Theme.cycle.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.cycle.opacity(0.22), lineWidth: 1)
            }
        }
    }

    func daySessionList(_ sessions: [WorkoutSession]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionLabel("已记录")

            ForEach(sessions) { session in
                Button {
                    sessionSheet = SessionSheet(session: session, isNew: false)
                } label: {
                    sessionRow(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .black))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 20, height: 20)
                .background(Theme.cobalt, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(String(session.dayTitle.prefix(40)))
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(session.exerciseCount) 个动作 · \(session.durationMinutes) 分钟 · \(Int(session.volume)) kg")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    func dayExerciseList(_ day: PlanDay, completed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            sectionLabel("计划动作")

            ForEach(Array(day.exercises.prefix(4))) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(completed ? Theme.cobalt : Theme.lime)
                        .frame(width: 5, height: 5)
                    Text(item.displayName)
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(item.targetText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.vertical, 6)
            }

            if day.exercises.count > 4 {
                Text("还有 \(day.exercises.count - 4) 个动作")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    func dayActions(
        plannedDay: PlanDay?,
        plan: TrainingPlan?,
        planCompleted: Bool,
        inProgress: Bool,
        sessions: [WorkoutSession],
        period: PeriodDay?
    ) -> some View {
        if let plannedDay, inProgress {
            let doneSets = store.completedSets(for: plannedDay)
            let plannedSets = store.plannedSets(for: plannedDay)
            Button {
                workoutDay = plannedDay
            } label: {
                Label("继续训练 · 已练 \(doneSets)/\(plannedSets) 组", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 2)
        } else if planCompleted {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.cobalt)
                Text("训练日已完成，记录已保存")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                Theme.cobalt.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        } else if period?.mode == .rest {
            EmptyView()
        } else if selectedDate <= calendar.startOfDay(for: Date()) {
            let recordedSets = plannedDay.map { store.completedSets(for: $0) } ?? 0
            Button {
                beginCalendarTraining(plan: plan)
            } label: {
                Label(
                    !sessions.isEmpty || recordedSets > 0
                        ? "再记一次训练"
                        : "记录这天的训练",
                    systemImage: "plus"
                )
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 2)
        }
    }

    var dayNutritionSection: some View {
        let logs = foodLogs(on: selectedDate)
        let totals = nutritionTotals(logs)
        let targets = store.nutritionTargets(for: selectedDate)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                sectionLabel("饮食")
                Spacer(minLength: 4)
                Text("\(Int(totals.kcal)) / \(targets.kcal) kcal")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("蛋白 \(Int(totals.protein))/\(targets.protein)g")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if !logs.isEmpty {
                ForEach(logs.prefix(3)) { log in
                    HStack(spacing: 8) {
                        Text(log.foodName)
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("\(log.meal.label) · \(Int(log.grams))g")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                        Spacer(minLength: 4)
                        Text("\(Int(log.kcal)) kcal")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                            .monospacedDigit()
                    }
                }
            }

            NavigationLink(value: TabRoute.nutrition(selectedDate)) {
                Text(logs.isEmpty ? "记录这天的饮食" : "查看 / 修改饮食")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 3)
        }
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(AppType.caption)
            .foregroundStyle(Theme.secondaryText)
    }
}
