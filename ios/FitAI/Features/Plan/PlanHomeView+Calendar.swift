import SwiftUI

extension PlanHomeView {
    // MARK: - Calendar

    func calendarCard(plan: TrainingPlan?) -> some View {
        let days = calendarDays
        let key: (Date) -> Date = { calendar.startOfDay(for: $0) }
        let sessionsByDay = Dictionary(grouping: store.sessions) { key($0.date) }
        let foodByDay = Dictionary(grouping: store.foodLogs) { key($0.date) }
        var planByDay: [Date: PlanDay] = [:]
        var completedPlanDayIDs = Set<UUID>()
        if let plan {
            for day in plan.days where day.skippedAt == nil {
                if store.isPlanDayCompleted(day) {
                    completedPlanDayIDs.insert(day.id)
                }
                if let scheduled = plan.scheduledDate(for: day) {
                    planByDay[key(scheduled)] = day
                }
            }
        }
        let periodDays = Set(days.filter { store.isPeriodDate($0) }.map(key))
        let year = calendar.component(.year, from: visibleMonth)
        let month = calendar.component(.month, from: visibleMonth)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("月历")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 4)

                monthButton(systemName: "chevron.left") {
                    shiftMonth(-1)
                }

                VStack(spacing: 1) {
                    Text("\(month)月")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(String(year))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .frame(width: 62)

                monthButton(systemName: "chevron.right") {
                    shiftMonth(1)
                }
            }

            HStack(spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(days, id: \.self) { date in
                    calendarCell(
                        date,
                        sessionsByDay: sessionsByDay,
                        foodByDay: foodByDay,
                        planByDay: planByDay,
                        completedPlanDayIDs: completedPlanDayIDs,
                        periodDays: periodDays
                    )
                }
            }
            .motionAnimation(Motion.smooth, value: visibleMonth)

            HStack(spacing: 11) {
                legendDot(color: Theme.secondary, label: "完成", filled: true)
                legendDot(color: Theme.primary, label: "计划", filled: false)
                legendDot(color: Theme.primary, label: "饮食", filled: true)
                legendDot(color: Theme.secondary, label: "经期", filled: false)
            }
            .padding(.top, 2)
        }
        .card()
    }

    func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.smooth) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(
                    Theme.ink.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(SubtlePressStyle())
    }

    func legendDot(color: Color, label: String, filled: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(filled ? color : Color.clear)
                .overlay {
                    Circle()
                        .stroke(color, lineWidth: filled ? 0 : 1)
                }
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    func calendarCell(
        _ date: Date,
        sessionsByDay: [Date: [WorkoutSession]],
        foodByDay: [Date: [FoodLog]],
        planByDay: [Date: PlanDay],
        completedPlanDayIDs: Set<UUID>,
        periodDays: Set<Date>
    ) -> some View {
        let key = calendar.startOfDay(for: date)
        let inMonth = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasSession = !(sessionsByDay[key]?.isEmpty ?? true)
        let plannedDay = planByDay[key]
        let plannedComplete = plannedDay.map { completedPlanDayIDs.contains($0.id) } ?? false
        let hasDraft = plannedDay.map { store.workoutDraft?.dayID == $0.id } ?? false
        let hasPlan = plannedDay != nil
        let hasFood = !(foodByDay[key]?.isEmpty ?? true)
        let hasPeriod = periodDays.contains(key)
        let isDone = hasSession || plannedComplete

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedDate = calendar.startOfDay(for: date)
                if !inMonth {
                    visibleMonth = startOfMonth(date)
                }
            }
            dayScrollRequest += 1
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(
                        .system(
                            size: 11.5,
                            weight: isToday ? .bold : .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(
                        isSelected
                            ? Theme.onPrimary
                            : (inMonth ? Theme.ink : Theme.tertiaryText)
                    )
                    .frame(maxWidth: .infinity)

                HStack(spacing: 2.5) {
                    if isDone {
                        Circle()
                            .fill(Theme.secondary)
                            .frame(width: 4, height: 4)
                    } else if hasPlan || hasDraft {
                        Circle()
                            .stroke(isSelected ? Theme.onPrimary : Theme.primary, lineWidth: 1)
                            .frame(width: 4, height: 4)
                    }
                    if hasFood {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 3.5, height: 3.5)
                    }
                    if hasPeriod {
                        Circle()
                            .stroke(Theme.cycle, lineWidth: 1)
                            .frame(width: 3.5, height: 3.5)
                    }
                    if !isDone && !hasPlan && !hasDraft && !hasFood && !hasPeriod {
                        Color.clear.frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.primary : (hasPlan ? Theme.ink.opacity(0.035) : Color.clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isToday && !isSelected ? Theme.cobalt : Color.clear,
                        lineWidth: 1.4
                    )
            }
            .opacity(inMonth ? 1 : 0.3)
            .scaleEffect(isSelected ? 1.03 : 1)
            .animation(Motion.quick, value: isSelected)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityLabel(
            accessibilityLabel(
                for: date,
                hasSession: hasSession,
                hasPlan: hasPlan,
                hasFood: hasFood,
                hasPeriod: hasPeriod
            )
        )
    }

    func accessibilityLabel(
        for date: Date,
        hasSession: Bool,
        hasPlan: Bool,
        hasFood: Bool,
        hasPeriod: Bool
    ) -> String {
        var parts = [date.formatted(.dateTime.month().day().weekday(.wide))]
        if hasSession { parts.append("有训练记录") }
        if hasPlan { parts.append("有训练计划") }
        if hasFood { parts.append("有饮食记录") }
        if hasPeriod { parts.append("处于经期") }
        return parts.joined(separator: "，")
    }
}
