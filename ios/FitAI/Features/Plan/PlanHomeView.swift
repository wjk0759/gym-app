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
    @State private var showPeriod = false
    @State private var sessionSheet: SessionSheet?
    @State private var editingDay: PlanDay?

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
                        if store.profile.sex == .female || store.plan != nil {
                            planToolBar
                        }
                        reviewStrip
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
            .navigationTitle("训练日历")
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
                        Button {
                            showSchedule = true
                        } label: {
                            Label("训练日期", systemImage: "calendar.badge.clock")
                        }
                        if store.profile.sex == .female {
                            Button {
                                showPeriod = true
                            } label: {
                                Label("经期安排", systemImage: "drop")
                            }
                        }
                        Button(role: .destructive) {
                            showRegenerate = true
                        } label: {
                            Label("重新生成计划", systemImage: "arrow.clockwise")
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
            .sheet(isPresented: $showPeriod) {
                PeriodScheduleView()
            }
            .fullScreenCover(item: $editingDay) { day in
                PlanEditorView(day: day)
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

    // MARK: - 训练数据快照

    private var recentTrainingSessions: [WorkoutSession] {
        let end = Date()
        let start = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: end)
        ) ?? end
        return store.sessions.filter { $0.date >= start && $0.date <= end }
    }

    private var trainingSnapshotCard: some View {
        let recent = recentTrainingSessions
        let volume = recent.reduce(0) { $0 + $1.volume }

        return NavigationLink {
            WorkoutHistoryView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(
                        Theme.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("训练数据 · 最近 30 天")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(recent.isEmpty
                         ? "还没有训练记录"
                         : "\(recent.count) 次训练 · \(Int(volume).formatted()) kg 容量")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 6)

                Text("查看趋势 ›")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .card(padding: 12)
    }

    // MARK: - 计划工具与复盘入口

    private var planToolBar: some View {
        HStack(spacing: 8) {
            Button {
                showSchedule = true
            } label: {
                Label("训练日期", systemImage: "calendar.badge.clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.accent.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)

            if store.profile.sex == .female {
                Button {
                    showPeriod = true
                } label: {
                    Label("经期", systemImage: "drop.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.danger.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("回到今天") {
                goToToday()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var reviewStrip: some View {
        let review = PlanReviewEngine.make(store: store, period: .month)
        return NavigationLink {
            PlanReviewView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("数据复盘 · \(review.period.title)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(review.current.sessions.count) 次训练 · \(review.current.loggedFoodDays) 天饮食记录")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)
                Text("查看报告 ›")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 日历

    private func calendarCard(plan: TrainingPlan?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                monthButton(systemName: "chevron.left") {
                    shiftMonth(-1)
                }

                Spacer(minLength: 4)

                Button {
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        goToToday()
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(monthTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("训练 · 饮食 · 计划")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))
                .accessibilityLabel("回到今天")

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
                ForEach(calendarDays, id: \.self) { date in
                    calendarCell(date, plan: plan)
                }
            }
            .motionAnimation(Motion.smooth, value: visibleMonth)

            HStack(spacing: 13) {
                legendDot(color: Theme.accent, label: "完成训练", filled: true)
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

    private func calendarCell(_ date: Date, plan: TrainingPlan?) -> some View {
        let inMonth = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasSession = !sessions(on: date).isEmpty
        let hasPlan = planDay(on: date, plan: plan) != nil
        let hasFood = !foodLogs(on: date).isEmpty
        let hasPeriod = store.isPeriodDate(date)

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
                    if hasSession {
                        Circle().fill(Theme.accent).frame(width: 4, height: 4)
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
                    if !hasSession && !hasPlan && !hasFood && !hasPeriod {
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

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDate.formatted(.dateTime.month().day().weekday(.wide)))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(daySessions.isEmpty
                         ? (plannedDay == nil ? "休息日" : "计划训练日")
                         : "完成 \(daySessions.count) 次训练")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
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

            if let period = store.periodDay(for: selectedDate) {
                HStack(spacing: 7) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Theme.danger)
                    Text("经期第 \(period.day) 天 · \(period.mode.title)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
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
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24, height: 24)
                            .background(Theme.accent.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(session.dayTitle.prefix(40)))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
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
                            .foregroundStyle(.white)
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

            if store.periodDay(for: selectedDate)?.mode == .rest {
                Text("经期休息日：训练计划保留，但今天不要求力量训练。散步、拉伸和补铁优先。")
                    .font(.caption2)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            } else if selectedDate <= calendar.startOfDay(for: Date()) {
                Button {
                    beginCalendarTraining(plan: plan)
                } label: {
                    Label(
                        daySessions.isEmpty ? "记录这天的训练" : "补记一次训练",
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
                            .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
                                    .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
                    Text("v\(plan.version) · \(plan.days.count) 个训练日 · 本周完成 \(completed)/\(max(1, store.profile.weeklyDays))")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 8)
                Button {
                    showRegenerate = true
                } label: {
                    Text("重新生成")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
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
        let sets = (plannedDay?.exercises ?? []).flatMap { item in
            let reps = Int(WorkoutPickerOptions.normalizedReps(item.reps)) ?? 10
            let baseWeight = max(0, item.weightKG ?? 0)
            let weight = isLight && baseWeight > 0
                ? ((baseWeight * 0.8) * 2).rounded() / 2
                : baseWeight
            let setCount = isLight ? max(2, item.sets - 1) : item.sets
            return (0..<max(1, setCount)).map { index in
                SetLog(
                    slug: item.slug,
                    setIndex: index + 1,
                    weightKG: weight,
                    reps: reps,
                    rpe: item.rpe
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
                sets: sets
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
                                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
