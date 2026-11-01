import SwiftUI

/// The record tab as a printed training journal.
///
/// Everything the old screen could do is still here: month calendar, schedule
/// changes, plan editing, workout history, period mode, progress and the plan
/// version list. The difference is hierarchy: the month reads as a cover, the
/// calendar as a date grid, and one selected day as a page.
struct PlanHomeView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedDate = Date()
    @State private var visibleMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()
    @State private var showRegenerate = false
    @State private var showHistory = false
    @State private var showSchedule = false
    @State private var sessionSheet: SessionSheet?
    @State private var editingDay: PlanDay?
    @State private var workoutDay: PlanDay?
    @State private var dayScrollRequest = 0

    private struct SessionSheet: Identifiable {
        let id = UUID()
        let session: WorkoutSession
        let isNew: Bool
    }

    private struct MonthStats {
        var sessions = 0
        var foodDays = 0
        var volume: Double = 0
        var minutes = 0
        var completedPlanDays = 0
        var plannedDays = 0

        var completion: Double {
            plannedDays > 0 ? Double(completedPlanDays) / Double(plannedDays) : 0
        }
    }

    private struct DayStatus {
        let text: String
        let accent: Color
        let filled: Bool
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                AppScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        topBar
                        header
                        quickActions

                        if store.isGenerating {
                            generatingCard
                        } else {
                            monthCover
                            calendarCard(plan: store.plan)
                            selectedDayCard(plan: store.plan)
                                .id("selected-day")
                            trainingDataCard

                            if let plan = store.plan {
                                planSummaryCard(plan)
                            } else {
                                emptyPlanCard
                            }
                        }
                    }
                    .appPagePadding()
                    .appReadableContent()
                    .padding(.top, 2)
                    .padding(.bottom, 28)
                }
                .background(AppBackground())
                .navigationTitle("")
                .navigationBarHidden(true)
                .sheet(isPresented: $showHistory) {
                    PlanHistoryView()
                }
                .sheet(item: $sessionSheet) { item in
                    WorkoutDetailView(session: item.session, isNew: item.isNew)
                }
                .sheet(isPresented: $showSchedule) {
                    PlanScheduleView()
                }
                .fullScreenCover(item: $editingDay) { day in
                    PlanEditorView(day: day)
                }
                .fullScreenCover(item: $workoutDay) { day in
                    WorkoutSessionView(
                        day: day,
                        periodMode: store.periodDay(for: day.date ?? selectedDate)?.mode
                    )
                }
                .confirmationDialog(
                    "重新生成计划？",
                    isPresented: $showRegenerate,
                    titleVisibility: .visible
                ) {
                    Button("重新生成", role: .destructive) {
                        store.generatePlan()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("当前计划会被归档，历史训练记录保留。")
                }
                .onChange(of: dayScrollRequest) { _, _ in
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo("selected-day", anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Motion.smooth) {
                    goToToday()
                }
            } label: {
                Label("回到今天", systemImage: "arrow.uturn.backward")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Theme.paper, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .buttonStyle(SubtlePressStyle(scale: 0.96))

            Spacer(minLength: 0)

            Menu {
                Button {
                    showHistory = true
                } label: {
                    Label("计划版本历史", systemImage: "clock.arrow.circlepath")
                }
                if store.plan != nil {
                    Button(role: .destructive) {
                        showRegenerate = true
                    } label: {
                        Label("重新生成计划", systemImage: "arrow.clockwise")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.paper, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .accessibilityLabel("更多计划操作")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TRAINING LOG / 记录")
                    .font(AppType.overline)
                    .tracking(1.5)
                    .foregroundStyle(Theme.cobalt)

                Text("训练手账")
                    .font(AppType.display)
                    .tracking(-0.9)
                    .foregroundStyle(Theme.ink)

                Text("翻回去看，才知道自己走了多远。")
                    .font(AppType.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            monthStamp
        }
        .padding(.top, 2)
    }

    private var monthStamp: some View {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        let month = components.month ?? 1
        let year = components.year ?? calendar.component(.year, from: Date())

        return VStack(spacing: 0) {
            Text("\(month)")
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text("月")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.cobalt)
            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 22, height: 1)
                .padding(.vertical, 3)
            Text(String(year))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(width: 54, height: 64)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.2)
        }
        .rotationEffect(.degrees(-3))
        .accessibilityHidden(true)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 8) {
            quickAction(title: "训练日期", symbol: "calendar.badge.clock", accent: Theme.primary) {
                showSchedule = true
            }

            NavigationLink {
                WorkoutHistoryView()
            } label: {
                quickActionLabel(
                    title: "训练记录",
                    symbol: "clock.arrow.circlepath",
                    accent: Theme.ink,
                    foreground: Theme.onAccent
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            NavigationLink {
                ProgressOverviewView()
            } label: {
                quickActionLabel(
                    title: "变化",
                    symbol: "chart.xyaxis.line",
                    accent: Theme.primary
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            if store.profile.sex == .female {
                SheetPresentingButton {
                    quickActionLabel(
                        title: "经期",
                        symbol: "drop.fill",
                        accent: Theme.secondary,
                        foreground: Theme.onAccent
                    )
                } sheet: {
                    PeriodScheduleView()
                }
            }
        }
    }

    private func quickAction(
        title: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            quickActionLabel(title: title, symbol: symbol, accent: accent)
        }
        .buttonStyle(CardPressStyle(scale: 0.97))
    }

    private func quickActionLabel(
        title: String,
        symbol: String,
        accent: Color,
        foreground: Color = Theme.onPrimary
    ) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)
                .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - Month cover

    private var visibleMonthStats: MonthStats {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth) else {
            return MonthStats()
        }

        var stats = MonthStats()
        let monthSessions = store.sessions.filter { interval.contains($0.date) }
        stats.sessions = monthSessions.count
        stats.volume = monthSessions.reduce(0) { $0 + $1.volume }
        stats.minutes = monthSessions.reduce(0) { $0 + $1.durationMinutes }
        stats.foodDays = Set(
            store.foodLogs
                .filter { interval.contains($0.date) }
                .map { FitnessDate.key($0.date) }
        ).count

        if let plan = store.plan {
            for day in plan.days {
                guard day.skippedAt == nil,
                      let date = plan.scheduledDate(for: day),
                      interval.contains(date) else { continue }
                stats.plannedDays += 1
                if store.isPlanDayCompleted(day) {
                    stats.completedPlanDays += 1
                }
            }
        }

        return stats
    }

    private var monthCover: some View {
        let stats = visibleMonthStats
        let year = calendar.component(.year, from: visibleMonth)
        let completionText = stats.plannedDays == 0
            ? "—"
            : "\(Int(stats.completion * 100))%"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("MONTH / \(monthLabel)")
                    .font(AppType.overline)
                    .tracking(1.4)
                    .foregroundStyle(Theme.onMedia.opacity(0.9))
                Spacer()
                Text(String(year))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.onMedia.opacity(0.78))
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(stats.sessions)")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("次训练")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.onMedia)
                    Text(isCurrentVisibleMonth ? "本月" : "当月")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.onMedia.opacity(0.72))
                }
                .padding(.bottom, 5)

                Spacer(minLength: 6)

                ProgressRing(
                    progress: stats.completion,
                    lineWidth: 5,
                    color: Theme.onMedia,
                    track: Theme.onMedia.opacity(0.22)
                )
                .frame(width: 46, height: 46)
                .overlay {
                    Text(completionText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.onMedia)
                }
                .padding(.bottom, 2)
            }

            Text(monthCoverNote(stats))
                .font(AppType.caption)
                .foregroundStyle(Theme.onMedia.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Theme.onMedia.opacity(0.22))
                .frame(height: 1)

            HStack(spacing: 10) {
                monthStat(
                    value: Int(stats.volume).formatted(),
                    unit: "kg",
                    label: "训练容量"
                )
                monthStat(
                    value: "\(stats.minutes)",
                    unit: "分钟",
                    label: "累计时长"
                )
                monthStat(
                    value: stats.plannedDays == 0
                        ? "—"
                        : "\(stats.completedPlanDays)/\(stats.plannedDays)",
                    unit: "",
                    label: "计划完成"
                )
            }
        }
        .padding(18)
        .background(
            Theme.inkSolid,
            in: RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.5)
        }
    }

    private func monthStat(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onMedia)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.onMedia.opacity(0.78))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.onMedia.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func monthCoverNote(_ stats: MonthStats) -> String {
        if isFutureVisibleMonth {
            return "\(monthLabel)还没开始。先把计划排好，到时候按页练。"
        }
        if stats.sessions == 0 {
            if isCurrentVisibleMonth {
                return "这个月还没有训练记录。今天写下第一笔，就有得翻了。"
            }
            return "这个月没有训练记录。空页也是记录的一部分。"
        }
        if isCurrentVisibleMonth {
            let remaining = max(
                0,
                store.currentWeekPlannedCount - store.currentWeekCompletedCount
            )
            if remaining > 0 {
                return "本周还差 \(remaining) 次训练，日历上已经留好位置。"
            }
            return "本周计划已经完成。剩下的时间留给恢复。"
        }
        return "这是 \(monthLabel) 的记录，训练和饮食都留在这本账里。"
    }

    private var isCurrentVisibleMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    private var isFutureVisibleMonth: Bool {
        startOfMonth(visibleMonth) > startOfMonth(Date())
    }

    private var monthLabel: String {
        "\(calendar.component(.month, from: visibleMonth))月"
    }

    // MARK: - Calendar

    private func calendarCard(plan: TrainingPlan?) -> some View {
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

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
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

    private func legendDot(color: Color, label: String, filled: Bool) -> some View {
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

    private func calendarCell(
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

    private func accessibilityLabel(
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

    // MARK: - Selected day

    private func selectedDayCard(plan: TrainingPlan?) -> some View {
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
                dayMetrics(plannedDay: plannedDay, sessions: daySessions, completed: planCompleted)
                dayProgress(plannedDay: plannedDay, completed: planCompleted)
            } else if !daySessions.isEmpty {
                dayMetrics(plannedDay: nil, sessions: daySessions, completed: false)
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
        .editorialCard(accent: status.accent)
    }

    private func dayStatus(
        planCompleted: Bool,
        inProgress: Bool,
        planned: Bool,
        hasSessions: Bool,
        period: PeriodDay?
    ) -> DayStatus {
        if planCompleted {
            return DayStatus(text: "已完成", accent: Theme.cobalt, filled: true)
        }
        if inProgress {
            return DayStatus(text: "进行中", accent: Theme.lime, filled: true)
        }
        if planned {
            return DayStatus(text: "计划日", accent: Theme.cobalt, filled: false)
        }
        if hasSessions {
            return DayStatus(text: "已记录", accent: Theme.cobalt, filled: true)
        }
        if period?.mode == .rest {
            return DayStatus(text: "休息日", accent: Theme.cycle, filled: false)
        }
        return DayStatus(text: "休息日", accent: Theme.tertiaryText, filled: false)
    }

    private func dayHeader(
        plannedDay: PlanDay?,
        sessions: [WorkoutSession],
        period: PeriodDay?,
        status: DayStatus
    ) -> some View {
        let title = plannedDay?.title
            ?? sessions.first?.dayTitle
            ?? (period?.mode == .rest ? "经期休息" : "休息日")
        let subtitle: String
        if let plannedDay {
            subtitle = plannedDay.focusText.isEmpty ? "按计划完成今天的训练。" : plannedDay.focusText
        } else if !sessions.isEmpty {
            let volume = sessions.reduce(0) { $0 + $1.volume }
            subtitle = "\(sessions.count) 次训练 · 共 \(Int(volume)) kg 容量"
        } else if period?.mode == .rest {
            subtitle = "今天不要求力量训练。散步、拉伸和补铁优先。"
        } else {
            subtitle = "没有安排。休息、走路、拉伸，都算恢复。"
        }

        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                Text(dayEyebrow(selectedDate))
                    .font(AppType.overline)
                    .tracking(1.1)
                    .foregroundStyle(Theme.cobalt)

                Spacer(minLength: 0)

                Text(status.text)
                    .font(AppType.micro)
                    .foregroundStyle(status.filled ? Theme.onAccent : Theme.secondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        status.filled
                            ? status.accent
                            : status.accent.opacity(0.12),
                        in: Capsule(style: .continuous)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                Theme.ink.opacity(status.filled ? 0.14 : 0),
                                lineWidth: 1
                            )
                    }
            }

            Text(title)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dayPlanMeta(_ day: PlanDay) -> some View {
        HStack(spacing: 8) {
            Text("第 \(day.weekIndex) 周 · \(day.exercises.count) 个动作 · \(day.estimatedMinutes) 分钟")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Button {
                Haptics.tap()
                editingDay = day
            } label: {
                Label("编辑", systemImage: "slider.horizontal.3")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
    }

    private func dayMetrics(
        plannedDay: PlanDay?,
        sessions: [WorkoutSession],
        completed: Bool
    ) -> some View {
        HStack(spacing: 8) {
            if let plannedDay {
                let plannedSets = store.plannedSets(for: plannedDay)
                let doneSets = store.completedSets(for: plannedDay)
                EditorialMetric(
                    title: "动作",
                    value: "\(plannedDay.exercises.count)",
                    unit: "个"
                )
                EditorialMetric(
                    title: "预计",
                    value: "\(plannedDay.estimatedMinutes)",
                    unit: "分钟"
                )
                EditorialMetric(
                    title: "完成组",
                    value: completed ? "\(plannedSets)" : "\(doneSets)/\(plannedSets)"
                )
            } else {
                let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
                let volume = sessions.reduce(0) { $0 + $1.volume }
                EditorialMetric(title: "记录", value: "\(sessions.count)", unit: "次")
                EditorialMetric(title: "时长", value: "\(minutes)", unit: "分钟")
                EditorialMetric(title: "容量", value: "\(Int(volume))", unit: "kg")
            }
        }
    }

    private func dayProgress(plannedDay: PlanDay, completed: Bool) -> some View {
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
    private func periodBanner(_ period: PeriodDay?) -> some View {
        if let period {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.cycle)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("经期第 \(period.day) 天 · \(period.mode.title)")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(period.mode.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }

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

    private func daySessionList(_ sessions: [WorkoutSession]) -> some View {
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

    private func sessionRow(_ session: WorkoutSession) -> some View {
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

    private func dayExerciseList(_ day: PlanDay, completed: Bool) -> some View {
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
    private func dayActions(
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
        } else {
            Text("未来日期：可先编辑计划，训练当天再记录。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private var dayNutritionSection: some View {
        let logs = foodLogs(on: selectedDate)
        let totals = nutritionTotals(logs)
        let targets = DietPlanner.targets(profile: store.profile)

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

            if logs.isEmpty {
                Text("这天还没有饮食记录。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            } else {
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

            NavigationLink {
                NutritionView(date: selectedDate)
            } label: {
                Text(logs.isEmpty ? "记录这天的饮食" : "查看 / 修改饮食")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 3)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(AppType.overline)
            .tracking(0.8)
            .foregroundStyle(Theme.cobalt)
    }

    // MARK: - Training data

    private var recentTrainingSessions: [WorkoutSession] {
        let end = Date()
        let start = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: end)
        ) ?? end
        return store.sessions.filter { $0.date >= start && $0.date <= end }
    }

    private var trainingDataCard: some View {
        let recent = recentTrainingSessions
        let volume = recent.reduce(0) { $0 + $1.volume }
        let sets = recent.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let minutes = recent.reduce(0) { $0 + $1.durationMinutes }
        let bars = trainingWeekBars
        let recentSessions = recent.sorted { $0.date > $1.date }
        let averageMinutes = recent.isEmpty ? 0 : minutes / recent.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练数据")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("最近 30 天 · 按实际训练日期统计")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Text("全部记录 ›")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                dataMetric(value: "\(recent.count)", unit: "次", label: "训练")
                dataMetric(value: Int(volume).formatted(), unit: "kg", label: "容量")
                dataMetric(value: "\(sets)", unit: "组", label: "组数")
                dataMetric(value: "\(averageMinutes)", unit: "分钟", label: "平均")
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == bars.count - 1 ? Theme.lime : Theme.cobalt)
                            .frame(
                                height: CGFloat(
                                    max(
                                        4,
                                        64 * bar.value / max(bars.map { $0.value }.max() ?? 1, 1)
                                    )
                                )
                            )
                        Text(bar.label)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 88)

            if !recentSessions.isEmpty {
                InkDivider()

                Text("最近训练")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                ForEach(recentSessions.prefix(3)) { session in
                    Button {
                        sessionSheet = SessionSheet(session: session, isNew: false)
                    } label: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(session.dayTitle.prefix(40)))
                                    .font(AppType.callout)
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.tertiaryText)
                            }

                            Spacer(minLength: 4)

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Theme.cobalt)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Theme.tertiaryText)
                            }

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func dataMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            Theme.ink.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var trainingWeekBars: [(label: String, value: Double)] {
        let monday = mondayOfWeek(Date())
        let labels = ["-3周", "-2周", "上周", "本周"]
        return (0..<4).map { index -> (label: String, value: Double) in
            let weekStart = calendar.date(
                byAdding: .day,
                value: -7 * (3 - index),
                to: monday
            ) ?? monday
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let value = store.sessions
                .filter { $0.date >= weekStart && $0.date < weekEnd }
                .reduce(0) { $0 + $1.volume }
            return (label: labels[index], value: value)
        }
    }

    // MARK: - Plan

    private func planSummaryCard(_ plan: TrainingPlan) -> some View {
        let completed = store.currentWeekSessions.count
        let planned = max(1, store.currentWeekPlannedCount)
        let progress = min(1, Double(completed) / Double(planned))

        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("PLAN / 当前计划")
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

    // MARK: - Empty and generating

    private var generatingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 正在编排")
                    .font(AppType.overline)
                    .tracking(1.2)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                ProgressView()
                    .tint(Theme.cobalt)
            }

            Text("4 周计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)

            Text("正在匹配动作、分配训练日、校验器械与伤病限制。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .editorialCard(accent: Theme.lime)
    }

    private var emptyPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还没有训练计划")
                .font(AppType.hero)
                .foregroundStyle(Theme.ink)

            Text("先让我按你的目标、器械和时间排一份 4 周计划。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .editorialCard(accent: Theme.lime)
    }

    // MARK: - Dates

    private var calendarDays: [Date] {
        let monthStart = startOfMonth(visibleMonth)
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayOffset = (weekday + 5) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -mondayOffset,
            to: monthStart
        ) else {
            return []
        }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func mondayOfWeek(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: start) ?? start
    }

    private func shiftMonth(_ amount: Int) {
        guard let next = calendar.date(
            byAdding: .month,
            value: amount,
            to: startOfMonth(visibleMonth)
        ) else {
            return
        }
        visibleMonth = next
        selectedDate = next
    }

    private func goToToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        visibleMonth = startOfMonth(today)
    }

    private func dayEyebrow(_ date: Date) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 · \(weekdayName(date))"
    }

    private func weekdayName(_ date: Date) -> String {
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return names[max(0, min(names.count - 1, index))]
    }

    // MARK: - Data

    private func planDay(on date: Date, plan: TrainingPlan?) -> PlanDay? {
        plan?.day(on: date)
    }

    private func beginCalendarTraining(plan: TrainingPlan?) {
        let plannedDay = planDay(on: selectedDate, plan: plan)
        let isLight = store.periodDay(for: selectedDate)?.mode == .light
        let time = calendar.date(
            bySettingHour: 19,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate

        let completedBySlug: [String: Int] = plannedDay.map { day in
            store.planDaySessions(day).reduce(into: [String: Int]()) { result, session in
                for set in session.sets where set.completed {
                    result[set.slug, default: 0] += 1
                }
            }
        } ?? [:]

        var sets: [SetLog] = []
        var plannedTotal = 0
        for item in plannedDay?.exercises ?? [] {
            let reps = Int(WorkoutPickerOptions.normalizedReps(item.reps)) ?? 10
            let baseWeight = max(0, item.weightKG ?? 0)
            let weight = isLight && baseWeight > 0
                ? ((baseWeight * 0.8) * 2).rounded() / 2
                : baseWeight
            let setCount = max(1, isLight ? max(2, item.sets - 1) : item.sets)
            plannedTotal += setCount
            let done = min(setCount, completedBySlug[item.slug, default: 0])
            let remaining = max(0, setCount - done)
            for index in 0..<remaining {
                sets.append(
                    SetLog(
                        slug: item.slug,
                        setIndex: done + index + 1,
                        weightKG: weight,
                        reps: reps,
                        rpe: item.rpe
                    )
                )
            }
        }

        sessionSheet = SessionSheet(
            session: WorkoutSession(
                date: time,
                dayTitle: plannedDay?.title ?? "训练记录",
                durationMinutes: plannedDay?.estimatedMinutes ?? 45,
                feeling: 3,
                notes: nil,
                sets: sets,
                programDayID: plannedDay?.id.uuidString,
                plannedSets: plannedTotal > 0 ? plannedTotal : nil
            ),
            isNew: true
        )
    }

    private func sessions(on date: Date) -> [WorkoutSession] {
        store.sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    private func foodLogs(on date: Date) -> [FoodLog] {
        store.foodLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func nutritionTotals(_ logs: [FoodLog]) -> NutritionTotals {
        logs.reduce(into: NutritionTotals()) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
        }
    }
}

// MARK: - Plan history

struct PlanHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let current = store.plan {
                        currentCard(current)
                    }

                    if store.planHistory.isEmpty {
                        noHistoryCard
                    } else {
                        Text("历史版本")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 2)

                        ForEach(store.planHistory) { plan in
                            historyCard(plan)
                        }
                    }

                    Text("最多保留最近 5 个版本。恢复历史版本不会删除训练记录。")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("计划历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func currentCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                TagChip(text: "当前使用", selected: true)
                Spacer()
                Text("v\(plan.version)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(plan.title)
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            Text("\(plan.days.count) 个训练日 · 开始于 \(plan.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.2)
        }
    }

    private var noHistoryCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("还没有旧版本")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
            Text("重新生成或让 AI 调整计划后，旧版本会保留在这里，方便对比和恢复。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func historyCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TagChip(text: "v\(plan.version)")
                Spacer()
                Text(plan.displayDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(plan.title)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text("\(plan.days.count) 个训练日 · \(plan.weeks) 周")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            Button {
                store.restorePlan(plan)
                dismiss()
            } label: {
                Label("恢复此版本", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
