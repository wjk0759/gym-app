import SwiftUI

/// Coach-first Today screen.
///
/// The old Today was a dashboard with eight competing sections. This version
/// keeps one primary action (today's training), one nutrition pulse and a
/// quiet coach note. Goal, weekly review and history stay available in a
/// disclosure below, so no capability is removed.
struct HomeV2View: View {
    @Environment(AppStore.self) private var store
    @Environment(WeatherStore.self) private var weather

    @State private var selectedDate = Date()
    @State private var showCompose = false
    @State private var pendingWorkoutDay: PlanDay?
    @State private var workoutDay: PlanDay?
    @State private var showBodyCheckIn = false
    @State private var bodyCheckInManual = false
    @State private var showTodayUnavailable = false
    @State private var showSchedule = false
    @State private var showCaptureHub = false
    @State private var captureKind: CaptureKind?
    @State private var didAutoPrompt = false

    private var selectedDay: PlanDay? {
        guard let plan = store.plan else { return nil }
        if Calendar.current.isDateInToday(selectedDate) {
            return store.todayDay
        }
        return plan.day(on: selectedDate)
    }

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var markedKeys: Set<String> {
        Set(
            (store.plan?.days ?? []).compactMap { day in
                store.plan?.scheduledDate(for: day).map { FitnessDate.key($0) }
            }
        )
    }

    private var completedKeys: Set<String> {
        Set(
            (store.plan?.days ?? []).compactMap { day in
                guard store.isPlanDayCompleted(day),
                      let date = store.plan?.scheduledDate(for: day) else { return nil }
                return FitnessDate.key(date)
            }
        )
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    if let advisory = weather.snapshot?.alertKind {
                        weatherBanner(advisory)
                    }
                    WeekStrip(
                        selectedDate: $selectedDate,
                        markedKeys: markedKeys,
                        completedKeys: completedKeys
                    )
                    coachNote
                    todaySection
                    nutritionPulse
                    quickActions
                    if !store.missedPlanDays.isEmpty {
                        missedPlanCard
                    }
                    moreSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                CaptureFAB {
                    showCaptureHub = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 88)
            }
            .fullScreenCover(isPresented: $showCompose, onDismiss: presentPendingWorkout) {
                if let day = selectedDay {
                    CustomWorkoutBuilderView(
                        title: day.title,
                        mode: .plan,
                        initialExercises: day.exercises,
                        templateDay: day
                    ) { plannedDay in
                        pendingWorkoutDay = plannedDay
                    }
                }
            }
            .fullScreenCover(item: $workoutDay) { day in
                WorkoutSessionView(
                    day: day,
                    periodMode: store.periodDay(for: day.date ?? selectedDate)?.mode
                )
            }
            .sheet(isPresented: $showBodyCheckIn) {
                BodyCheckInSheet(manual: bodyCheckInManual)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSchedule) {
                PlanScheduleView()
            }
            .sheet(isPresented: $showCaptureHub) {
                CaptureHubView { kind in
                    showCaptureHub = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        captureKind = kind
                    }
                }
            }
            .sheet(item: $captureKind) { kind in
                captureDestination(kind)
            }
            .confirmationDialog(
                "今天没空？",
                isPresented: $showTodayUnavailable,
                titleVisibility: .visible
            ) {
                if let day = store.todayDay {
                    if let target = store.nextFreePlanDate(after: Date(), excluding: day.id) {
                        Button("顺延到 \(FitnessDate.short(target))") {
                            store.deferPlanDay(day)
                        }
                    }
                    Button("这周少练一次") {
                        store.skipPlanDay(day)
                    }
                }
                Button("调整完整训练日期") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showSchedule = true
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("顺延会保留这次训练内容；少练一次不会算作未完成。")
            }
            .task {
                store.refreshWeeklyReview()
            }
            .onAppear {
                presentLaunchIfNeeded()
                guard !didAutoPrompt else { return }
                didAutoPrompt = true
                if store.bodyCheckInDue {
                    bodyCheckInManual = false
                    showBodyCheckIn = true
                }
            }
            .onChange(of: store.bodyCheckInFrequency) { _, _ in
                if store.bodyCheckInDue {
                    bodyCheckInManual = false
                    showBodyCheckIn = true
                }
            }
            .onChange(of: store.workoutLaunchDayID) { _, dayID in
                guard let dayID,
                      let day = store.plan?.days.first(where: { $0.id == dayID }) else {
                    return
                }
                store.workoutLaunchDayID = nil
                workoutDay = day
            }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeGreeting)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(store.profile.nickname.isEmpty ? "今天" : store.profile.nickname)
                    .font(AppType.title)
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            WeatherBadgeView()
            Button {
                store.selectedTab = 2
            } label: {
                CoachMark(size: 38)
            }
            .buttonStyle(SubtlePressStyle(scale: 0.94))
            .accessibilityLabel("找教练")
        }
        .padding(.top, 4)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好，今天只做一件事"
        case 12..<18: return "下午好，先把今天练明白"
        default: return "晚上好，练完就好好恢复"
        }
    }

    private func weatherBanner(_ kind: WeatherAlertKind) -> some View {
        HStack(spacing: 9) {
            Image(systemName: kind == .thunder ? "cloud.bolt.rain.fill" : "cloud.rain.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
            VStack(alignment: .leading, spacing: 2) {
                Text(advisoryTitle(kind))
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(advisoryDetail(kind))
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Theme.cobalt.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.cobalt.opacity(0.18), lineWidth: 1)
        }
    }

    private func advisoryTitle(_ kind: WeatherAlertKind) -> String {
        switch kind {
        case .rain: return "今天有雨，出门带伞"
        case .snow: return "雨雪天气，慢一点走"
        case .thunder: return "雷雨天气，减少户外停留"
        case .rainLikely: return "今天可能下雨"
        case .typhoon: return "风力很大，减少外出"
        }
    }

    private func advisoryDetail(_ kind: WeatherAlertKind) -> String {
        switch kind {
        case .rain: return "路面湿滑，训练前后注意保暖；如果通勤绕路，优先保证安全。"
        case .snow: return "路面可能结冰，避开急转和湿滑台阶，热身多花 3 分钟。"
        case .thunder: return "尽量避开空旷地带和积水路段，必要时把训练改到室内。"
        case .rainLikely: return "降雨概率较高，包里备好雨具，出门前再看一眼天气。"
        case .typhoon: return "远离广告牌、树木和临时搭建物，训练改到室内，别在风口停留。"
        }
    }

    // MARK: - Coach note

    private var coachNote: some View {
        HStack(alignment: .top, spacing: 10) {
            CoachMark(size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("教练笔记")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
                Text(coachLine)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var coachLine: String {
        if store.isGenerating {
            return "我在排这 4 周的计划，先按你的目标、器械和伤病来。"
        }
        guard let plan = store.plan else {
            return "先建一份 4 周计划，之后我只提醒你今天该做什么。"
        }
        guard let day = selectedDay else {
            return "今天是恢复日。睡够、吃够蛋白，比多练一场更有用。"
        }
        if store.isPlanDayCompleted(day) {
            return "今天已经练完，剩下的交给恢复。"
        }
        if let draft = store.draft(for: day.id) {
            return "上次练到第 \(draft.completedSets) 组，今天接着来。"
        }
        return "今天把「\(day.title)」练明白，别加戏。"
    }

    // MARK: - Today

    @ViewBuilder
    private var todaySection: some View {
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

    private var generatingCard: some View {
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

    private func loadingPill(_ title: String, done: Bool) -> some View {
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

    private func trainingCard(plan: TrainingPlan, day: PlanDay) -> some View {
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
                    .foregroundStyle(period.mode == .rest ? Theme.coral : Theme.cobalt)
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
                    store.selectedTab = 1
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .editorialCard(accent: completed ? Theme.cobalt : Theme.lime)
    }

    private var noPlanCard: some View {
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

    private func restCard(plan: TrainingPlan, period: PeriodDay?) -> some View {
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

    // MARK: - Nutrition

    private var nutritionPulse: some View {
        let targets = DietPlanner.targets(profile: store.profile)
        let consumed = store.todayNutrition
        let remaining = max(0, targets.kcal - Int(consumed.kcal))
        let proteinLeft = max(0, targets.protein - Int(consumed.protein))
        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))

        return NavigationLink {
            NutritionView()
        } label: {
            HStack(spacing: 12) {
                ProgressRing(progress: ratio, lineWidth: 6, color: Theme.lime)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text("\(Int(ratio * 100))%")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.ink)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日饮食")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("还能吃 \(remaining) kcal · 蛋白还差 \(proteinLeft)g")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 8) {
            quickTile(title: "记录身体", symbol: "figure.stand", accent: Theme.primary) {
                bodyCheckInManual = true
                showBodyCheckIn = true
            }
            NavigationLink {
                ProgressOverviewView()
            } label: {
                quickTileLabel(title: "变化", symbol: "chart.line.uptrend.xyaxis", accent: Theme.ink, foreground: Theme.onAccent)
            }
            .buttonStyle(CardPressStyle(scale: 0.985))

            quickTile(title: "问教练", symbol: "bubble.left.and.bubble.right", accent: Theme.primary) {
                store.selectedTab = 2
            }
        }
    }

    private func quickTile(
        title: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            quickTileLabel(title: title, symbol: symbol, accent: accent, foreground: Theme.onPrimary)
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    private func quickTileLabel(title: String, symbol: String, accent: Color, foreground: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - Missed and more

    private var missedPlanCard: some View {
        let missed = store.missedPlanDays
        return Group {
            if let first = missed.first,
               let plan = store.plan,
               let date = plan.scheduledDate(for: first) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("有 \(missed.count) 次没完成")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text(FitnessDate.short(date))
                            .font(AppType.micro)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    HStack(spacing: 14) {
                        Button("顺延这次") { store.deferPlanDay(first) }
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .buttonStyle(SubtlePressStyle())
                        Button("跳过这次") { store.skipPlanDay(first) }
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.tertiaryText)
                            .buttonStyle(SubtlePressStyle())
                        Spacer()
                    }
                }
                .padding(14)
                .background(Theme.coral.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.coral.opacity(0.28), lineWidth: 1)
                }
            }
        }
    }

    private var moreSection: some View {
        DisclosureGroup {
            VStack(spacing: 12) {
                weeklySummaryCard
                GoalCardView {
                    bodyCheckInManual = true
                    showBodyCheckIn = true
                }
                aiReviewCard
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("目标、周报和更多")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .tint(Theme.cobalt)
    }

    private var weeklySummaryCard: some View {
        let completion = store.weeklyCompletion
        let completed = store.currentWeekCompletedCount
        let planned = store.currentWeekPlannedCount
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本周完成")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(planned == 0 ? "本周全休" : "\(completed)/\(planned) 次")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            ProgressView(value: completion)
                .tint(Theme.cobalt)
            HStack(spacing: 8) {
                EditorialMetric(title: "累计训练", value: "\(store.sessions.count)", unit: "次")
                EditorialMetric(title: "总容量", value: "\(Int(store.totalVolume))", unit: "kg")
                EditorialMetric(title: "本周", value: "\(store.currentWeekSessions.count)", unit: "次")
            }
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var aiReviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI 复盘")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("刷新") {
                    store.refreshWeeklyReview(force: true)
                }
                .font(AppType.micro)
                .foregroundStyle(Theme.cobalt)
                .buttonStyle(SubtlePressStyle())
                .disabled(store.isReviewingWeekly)
            }
            if let review = store.weeklyReview {
                Text(review.summary)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = review.actions.first {
                    Text("下一步：\(action)")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
            } else if store.isReviewingWeekly {
                Text("教练正在读本周训练…")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                Text("完成一次训练后，这里会出现周复盘。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Button {
                store.requestPlanAdjustment()
            } label: {
                Label("和教练聊聊，再调整计划", systemImage: "bubble.left.and.bubble.right")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - Capture routing

    @ViewBuilder
    private func captureDestination(_ kind: CaptureKind) -> some View {
        switch kind {
        case .food:
            FoodPhotoAnalysisView()
        case .body:
            BodyPhotoAnalysisView()
        case .equipment:
            NavigationStack {
                EquipmentRecognitionView(
                    onSaved: { item in
                        store.toast = "已加入个人动作库：\(item.name)"
                    },
                    onRecognized: { result in
                        store.coachEquipmentResult = result
                    }
                )
            }
        case .action:
            VideoReviewView()
        }
    }

    // MARK: - Actions

    private func presentPendingWorkout() {
        guard let day = pendingWorkoutDay else { return }
        pendingWorkoutDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            workoutDay = day
        }
    }

    private func presentLaunchIfNeeded() {
        guard let dayID = store.workoutLaunchDayID,
              let day = store.plan?.days.first(where: { $0.id == dayID }) else {
            return
        }
        store.workoutLaunchDayID = nil
        workoutDay = day
    }
}
