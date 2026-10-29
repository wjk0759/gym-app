import SwiftUI

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

    private struct SessionSheet: Identifiable {
        let id = UUID()
        let session: WorkoutSession
        let isNew: Bool
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: AppLayout.sectionSpacing) {
                    if store.isGenerating {
                        generatingCard
                    } else {
                        planQuickActions
                        recordSummaryCard
                        calendarCard(plan: store.plan)
                        selectedDayCard(plan: store.plan)

                        if let plan = store.plan {
                            planSummaryCard(plan)
                        } else {
                            emptyCard
                        }
                    }
                }
                .appPagePadding()
                .appReadableContent()
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("今天") {
                        goToToday()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("更多计划操作")
                }
            }
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
        }
    }

    // MARK: - 计划快捷入口

    /// 只做月度计数，避免每次刷新都跑完整的复盘引擎（当前 + 上期 + KPI 趋势）。
    private var monthSummary: (sessions: Int, foodDays: Int) {
        guard let interval = calendar.dateInterval(of: .month, for: Date()) else {
            return (0, 0)
        }
        let sessions = store.sessions.lazy.filter { interval.contains($0.date) }.count
        let foodDays = Set(
            store.foodLogs.lazy
                .filter { interval.contains($0.date) }
                .map { FitnessDate.key($0.date) }
        ).count
        return (sessions, foodDays)
    }

    private var planQuickActions: some View {
        let summary = monthSummary

        return HStack(spacing: 10) {
            planActionTile(
                title: "训练日期",
                subtitle: "调整每周训练",
                icon: "calendar.badge.clock",
                tint: Theme.accent
            ) {
                showSchedule = true
            }

            if store.profile.sex == .female {
                SheetPresentingButton {
                    planActionTileLabel(
                        title: "经期",
                        subtitle: "轻量训练安排",
                        icon: "drop.fill",
                        tint: Theme.danger
                    )
                } sheet: {
                    PeriodScheduleView()
                }
            }

            NavigationLink {
                PlanReviewView()
            } label: {
                planActionTileLabel(
                    title: "数据复盘",
                    subtitle: "\(summary.sessions) 练 · \(summary.foodDays) 天饮食",
                    icon: "chart.bar.doc.horizontal",
                    tint: Theme.accent
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.98))
        }
    }

    private func planActionTile(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            planActionTileLabel(title: title, subtitle: subtitle, icon: icon, tint: tint)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.98))
    }

    private var recordSummaryCard: some View {
        let targets = DietPlanner.targets(profile: store.profile)
        let consumed = store.todayNutrition
        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))
        let today = Date()
        let todaySessions = sessions(on: today)
        let plannedDay = planDay(on: today, plan: store.plan)
        let plannedComplete = plannedDay.map { store.isPlanDayCompleted($0) } ?? false
        let plannedProgress = plannedDay.map { store.planDayProgress($0) } ?? 0
        let trainingText: String = plannedComplete
            ? "已完成"
            : (plannedDay == nil ? (todaySessions.isEmpty ? "休息日" : "已记录") : "待完成 \(Int(plannedProgress * 100))%")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今天 · 吃练记录")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("每天一笔，变化才有方向。")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                Text(today.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(Int(consumed.kcal))")
                    .font(.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                    .contentTransition(.numericText())
                Text("/ \(targets.kcal) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }

            ProgressView(value: ratio)
                .tint(Theme.accent)

            HStack(spacing: 10) {
                recordMetric(
                    title: "蛋白质",
                    value: "\(Int(consumed.protein)) / \(targets.protein)g",
                    icon: "bolt.fill",
                    color: Theme.accent
                )
                recordMetric(
                    title: "训练",
                    value: trainingText,
                    icon: plannedComplete ? "checkmark.seal.fill" : "figure.strengthtraining.traditional",
                    color: plannedComplete ? Theme.accent : Theme.warning
                )
            }

            HStack(spacing: 8) {
                NavigationLink {
                    NutritionView(date: today)
                } label: {
                    Label("补记饮食", systemImage: "fork.knife")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Theme.accent.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Label("训练记录", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Theme.surfaceStrong, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func recordMetric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiaryText)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func planActionTileLabel(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background {
                        SoftSurface(
                            cornerRadius: 10,
                            tint: tint.opacity(0.12),
                            stroke: tint.opacity(0.22)
                        )
                    }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            SoftSurface(
                cornerRadius: 16,
                tint: Theme.cardSurface,
                stroke: Theme.stroke
            )
        }
    }

    // MARK: - 日历

    private func calendarCard(plan: TrainingPlan?) -> some View {
        let days = calendarDays
        let key: (Date) -> Date = { calendar.startOfDay(for: $0) }
        let sessionsByDay = Dictionary(grouping: store.sessions) { key($0.date) }
        let foodByDay = Dictionary(grouping: store.foodLogs) { key($0.date) }
        var planByDay: [Date: PlanDay] = [:]
        var completedPlanDayIDs = Set<UUID>()
        if let plan {
            for day in plan.days {
                if store.isPlanDayCompleted(day) {
                    completedPlanDayIDs.insert(day.id)
                }
                if let scheduled = plan.scheduledDate(for: day) {
                    planByDay[key(scheduled)] = day
                }
            }
        }
        let periodDays = Set(days.filter { store.isPeriodDate($0) }.map(key))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                monthButton(systemName: "chevron.left") {
                    shiftMonth(-1)
                }

                Spacer(minLength: 4)

                VStack(spacing: 2) {
                    Text(monthTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text("训练 · 饮食 · 计划")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                monthButton(systemName: "chevron.right") {
                    shiftMonth(1)
                }
            }

            HStack(spacing: 4) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

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
                legendDot(color: Theme.accent, label: "完成训练", filled: true)
                legendDot(color: Theme.accent.opacity(0.42), label: "部分完成", filled: true)
                legendDot(color: Theme.accent.opacity(0.7), label: "训练计划", filled: false)
                legendDot(color: Theme.warning, label: "饮食记录", filled: true)
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
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 40, height: 40)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .buttonStyle(SubtlePressStyle())
    }

    private func legendDot(color: Color, label: String, filled: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(filled ? color : Color.clear)
                .overlay(Circle().stroke(color, lineWidth: filled ? 0 : 1))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9))
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

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedDate = calendar.startOfDay(for: date)
                if !inMonth {
                    visibleMonth = startOfMonth(date)
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isToday ? Theme.accent : Theme.secondaryText)
                    )
                    .frame(maxWidth: .infinity)

                HStack(spacing: 2.5) {
                    if hasSession || hasDraft || plannedComplete {
                        Circle()
                            .fill(plannedDay == nil || plannedComplete
                                  ? Theme.accent
                                  : Theme.accent.opacity(0.42))
                            .frame(width: 4, height: 4)
                    }
                    if hasPlan {
                        Circle()
                            .stroke(Theme.accent.opacity(0.75), lineWidth: 1)
                            .frame(width: 4, height: 4)
                    }
                    if hasFood {
                        Circle().fill(Theme.warning).frame(width: 4, height: 4)
                    }
                    if hasPeriod {
                        Circle().fill(Theme.danger).frame(width: 4, height: 4)
                    }
                    if !hasSession && !hasDraft && !hasPlan && !hasFood && !hasPeriod {
                        Color.clear.frame(width: 4, height: 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.16) : Color.white.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        isSelected
                            ? Theme.accent.opacity(0.7)
                            : (isToday ? Theme.accent.opacity(0.32) : Color.clear),
                        lineWidth: 1
                    )
            )
            .opacity(inMonth ? 1 : 0.32)
            .scaleEffect(isSelected ? 1.04 : 1)
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

    // MARK: - 选中日期

    private func selectedDayCard(plan: TrainingPlan?) -> some View {
        let daySessions = sessions(on: selectedDate)
        let plannedDay = planDay(on: selectedDate, plan: plan)
        let logs = foodLogs(on: selectedDate)
        let totals = nutritionTotals(logs)
        let plannedSets = plannedDay.map { store.plannedSets(for: $0) } ?? 0
        let doneSets = plannedDay.map { store.completedSets(for: $0) } ?? 0
        let planCompleted = plannedDay.map { store.isPlanDayCompleted($0) } ?? false
        let hasDraft = plannedDay.map { store.workoutDraft?.dayID == $0.id } ?? false
        let progress = plannedDay.map { store.planDayProgress($0) } ?? 0
        let subtitle: String
        if hasDraft && !planCompleted {
            subtitle = "训练进行中 · 已练 \(doneSets)/\(plannedSets) 组"
        } else if planCompleted {
            subtitle = "计划训练已完成"
        } else if plannedDay != nil, doneSets > 0 {
            subtitle = "已完成 \(doneSets)/\(plannedSets) 组 · 还差 \(max(0, plannedSets - doneSets)) 组"
        } else if daySessions.isEmpty {
            subtitle = plannedDay == nil ? "休息日" : "计划训练日"
        } else {
            subtitle = "完成 \(daySessions.count) 次训练"
        }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(planCompleted ? Theme.accent : Theme.tertiaryText)
                }
                Spacer()
                NavigationLink {
                    NutritionView(date: selectedDate)
                } label: {
                    Text("饮食 ›")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            if plannedDay != nil, doneSets > 0 {
                VStack(spacing: 5) {
                    ProgressView(value: progress)
                        .tint(planCompleted ? Theme.accent : Theme.warning)
                    HStack {
                        Text(planCompleted ? "全部 \(plannedSets) 组已完成" : "已记录 \(doneSets)/\(plannedSets) 组")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.top, 9)
            }

            if let period = store.periodDay(for: selectedDate) {
                HStack(spacing: 7) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.danger)
                    Text("经期第 \(period.day) 天 · \(period.mode.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                }
                .padding(9)
                .background(Theme.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 9)
            }

            sectionTitle("训练")

            if daySessions.isEmpty && plannedDay == nil {
                Text("这天没有训练安排，可以休息或调整计划。")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 7)
            }

            ForEach(daySessions) { session in
                Button {
                    sessionSheet = SessionSheet(session: session, isNew: false)
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: planCompleted ? "checkmark" : "circle.lefthalf.filled")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(session.dayTitle.prefix(40)))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(1)
                            Text("\(session.exerciseCount) 个动作 · \(session.durationMinutes) 分钟 · \(Int(session.volume)) kg")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(9)
                    .background(
                        Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 7)
            }

            if let plannedDay {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("计划 · 第 \(plannedDay.weekIndex) 周")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.accent)
                        Text(plannedDay.title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("\(plannedDay.focusText) · \(plannedDay.exercises.count) 个动作")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer(minLength: 4)
                    Button {
                        editingDay = plannedDay
                    } label: {
                        Text("编辑训练日 ›")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    Theme.accent.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.accent.opacity(0.13), lineWidth: 1)
                )
                .padding(.top, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(plannedDay.exercises.prefix(5)) { item in
                            Text(item.displayName)
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.tertiaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.035), in: Capsule())
                        }
                        if plannedDay.exercises.count > 5 {
                            Text("+\(plannedDay.exercises.count - 5)")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                }
                .padding(.top, 7)
            }

            if hasDraft, let plannedDay, !planCompleted {
                Button {
                    workoutDay = plannedDay
                } label: {
                    Label("继续训练 · 已练 \(doneSets)/\(plannedSets) 组", systemImage: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 9)
            } else if store.periodDay(for: selectedDate)?.mode == .rest {
                Text("经期休息日：训练计划保留，但今天不要求力量训练。散步、拉伸和补铁优先。")
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            } else if planCompleted {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                    Text("训练日已完成，记录已保存")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer(minLength: 0)
                }
                .padding(.top, 9)
            } else if selectedDate <= calendar.startOfDay(for: Date()) {
                Button {
                    beginCalendarTraining(plan: plan)
                } label: {
                    Label(
                        doneSets > 0
                            ? "再记一次训练"
                            : (daySessions.isEmpty ? "记录这天的训练" : "补记一次训练"),
                        systemImage: "plus"
                    )
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 9)
            } else {
                Text("未来日期：可先编辑计划，训练当天再记录。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 8)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.vertical, 13)

            HStack {
                sectionTitle("饮食", topPadding: 0)
                Spacer()
                Text("\(Int(totals.kcal)) kcal · 蛋白 \(Int(totals.protein))g")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if logs.isEmpty {
                Text("还没有饮食记录。")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 8)
            } else {
                ForEach(logs.prefix(3)) { log in
                    HStack {
                        Text(log.foodName)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.primaryText)
                        Text("\(log.meal.label) · \(Int(log.grams))g")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.tertiaryText)
                        Spacer()
                        Text("\(Int(log.kcal)) kcal")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.top, 6)
                }
            }

            NavigationLink {
                NutritionView(date: selectedDate)
            } label: {
                Text(logs.isEmpty ? "记录这天的饮食" : "查看 / 修改饮食")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 10)
        }
        .card()
    }

    private func sectionTitle(_ title: String, topPadding: CGFloat = 12) -> some View {
        Text(title)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundStyle(Theme.accent)
            .padding(.top, topPadding)
    }

    // MARK: - 训练数据

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
        let recentSessions = store.sessions.sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练数据")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("最近 30 天")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                }
                Spacer()
                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    Text("全部记录 ›")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                trainingMetric("\(recent.count)", "完成训练")
                trainingMetric("\(Int(volume))", "总容量 kg")
                trainingMetric("\(sets)", "总组数")
                trainingMetric(recent.isEmpty ? "0" : "\(minutes / recent.count)", "平均分钟")
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: 5) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.accent.opacity(0.95),
                                        Theme.accent.opacity(0.34)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                height: CGFloat(
                                    max(
                                        4,
                                        68 * bar.value / max(bars.map { $0.value }.max() ?? 1, 1)
                                    )
                                )
                            )
                        Text(bar.label)
                            .font(.system(size: 8.5))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 92)
            .padding(.top, 4)

            Text("按实际训练日期统计，容量只计算有记录的组数。")
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)

            if !recentSessions.isEmpty {
                Rectangle()
                    .fill(Theme.stroke)
                    .frame(height: 1)
                    .padding(.top, 2)

                HStack {
                    Text("最近训练")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                }
                .padding(.top, 2)

                ForEach(recentSessions.prefix(3)) { session in
                    Button {
                        sessionSheet = SessionSheet(session: session, isNew: false)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(session.dayTitle.prefix(40)))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.primaryText)
                                    .lineLimit(1)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.tertiaryText)
                                .padding(.leading, 2)
                        }
                        .padding(.top, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private func trainingMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
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

    // MARK: - 计划摘要

    private func planSummaryCard(_ plan: TrainingPlan) -> some View {
        let completed = store.currentWeekSessions.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前计划")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("v\(plan.version) · \(plan.days.count) 个训练日 · 本周完成 \(completed)/\(max(1, store.currentWeekPlannedCount))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 8)
            }

            Text("调整计划前，教练会先听你说最近训练中的时间、恢复、疼痛或负荷问题，再给出方案。")
                .font(.caption)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.requestPlanAdjustment()
            } label: {
                Label("和 AI 教练聊聊，再调整计划", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    // MARK: - 空状态与生成中

    private var generatingCard: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Theme.accent).scaleEffect(1.2)
            Text("正在编排计划…")
                .font(.headline)
            Text("按目标、器械、频率生成 4 周训练日")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 30)
    }

    private var emptyCard: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "还没有计划",
                message: "完成建档后可以生成 4 周计划，并随时编辑动作与组次。"
            )
            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - 日期与数据

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: visibleMonth)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

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

struct PlanHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 14) {
                    if let current = store.plan {
                        currentCard(current)
                    }

                    if store.planHistory.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "还没有历史版本",
                            message: "重新生成或让 AI 调整计划后，旧版本会保留在这里，方便对比和恢复。"
                        )
                    } else {
                        HStack {
                            Text("历史版本")
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Text("\(store.planHistory.count) 个")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top, 2)

                        ForEach(store.planHistory) { plan in
                            historyCard(plan)
                        }
                    }

                    Text("最多保留最近 5 个版本。恢复历史版本不会删除训练记录。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 12)
                }
                .padding(20)
                .padding(.bottom, 20)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("当前使用")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                Spacer()
                Text("v\(plan.version)")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(plan.title)
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            Text("\(plan.days.count) 个训练日 · 开始于 \(plan.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func historyCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("v\(plan.version)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(plan.displayDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(plan.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            Text("\(plan.days.count) 个训练日 · \(plan.weeks) 周")
                .font(.caption)
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
        .card()
    }
}
