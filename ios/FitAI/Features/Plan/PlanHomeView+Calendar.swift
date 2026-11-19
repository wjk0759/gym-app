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
                monthButton(systemName: "chevron.left") {
                    shiftMonth(-1)
                }

                Spacer(minLength: 0)

                Text("\(String(year))年\(month)月")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 0)

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

                Circle()
                    .fill(isSelected ? Theme.onPrimary : (isDone ? Theme.secondary : Theme.primary))
                    .frame(width: 4, height: 4)
                    .opacity(isDone || hasPlan || hasDraft || hasFood || hasPeriod ? 1 : 0)
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
