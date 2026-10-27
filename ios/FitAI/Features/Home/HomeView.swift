import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store

    @State private var showCompose = false
    @State private var pendingWorkoutDay: PlanDay?
    @State private var workoutDay: PlanDay?
    @State private var showBodyCheckIn = false
    @State private var bodyCheckInManual = false
    @State private var didAutoPrompt = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    greeting

                    GoalCardView {
                        bodyCheckInManual = true
                        showBodyCheckIn = true
                    }

                    if store.isGenerating {
                        generatingCard
                    } else if let plan = store.plan {
                        if store.todayPeriod?.mode == .rest {
                            nutritionCard
                            restCard(plan: plan, period: store.todayPeriod)
                        } else if let day = store.todayDay {
                            trainingCard(plan: plan, day: day, period: store.todayPeriod)
                            nutritionCard
                        } else {
                            nutritionCard
                            restCard(plan: plan, period: store.todayPeriod)
                        }

                        weekCard

                        if store.todayPeriod?.mode != .rest {
                            aiReviewCard(plan: plan)
                        }
                    } else {
                        noPlanCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCompose, onDismiss: presentPendingWorkout) {
                if let day = store.todayDay {
                    CustomWorkoutBuilderView(
                        title: day.title,
                        mode: .plan,
                        initialExercises: day.exercises
                    ) { plannedDay in
                        pendingWorkoutDay = plannedDay
                    }
                }
            }
            .fullScreenCover(item: $workoutDay) { day in
                WorkoutSessionView(day: day, periodMode: store.todayPeriod?.mode)
            }
            .sheet(isPresented: $showBodyCheckIn) {
                BodyCheckInSheet(manual: bodyCheckInManual)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
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
        }
    }

    // MARK: - 顶部

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(timeGreeting)，\(store.profile.nickname)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    // MARK: - 计划状态

    private var generatingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.2)
            Text("正在为你编排 4 周计划…")
                .font(.headline)
            Text("根据目标、分化、器械和每周 \(store.profile.weeklyDays) 天的时间安排")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 30)
    }

    private var noPlanCard: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                icon: "wand.and.stars",
                title: "还没有训练计划",
                message: "生成一份 4 周计划，之后会随训练记录自动调整。"
            )
            Button("生成计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func trainingCard(plan: TrainingPlan, day: PlanDay, period: PeriodDay?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(period == nil ? "今日训练" : "经期轻量版")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(period == nil ? Theme.accent : Theme.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (period == nil ? Theme.accent : Theme.danger).opacity(0.12),
                        in: Capsule()
                    )
                Spacer()
                Text("第 \(store.currentPlanWeek) 周 / 共 \(plan.weeks) 周")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(day.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(day.focusText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            if let period {
                Text(period.mode == .rest
                     ? "经期已设为直接休息，今天不安排力量训练。"
                     : "经期第 \(period.day) 天：自动少 1 组、负重约 80%；腹痛明显时改为散步或休息。")
                    .font(.caption)
                    .foregroundStyle(period.mode == .rest ? Theme.danger : Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 24) {
                inlineMetric(title: "动作", value: "\(day.exercises.count) 个")
                inlineMetric(title: "预计", value: "\(day.estimatedMinutes) 分钟")
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(day.exercises.prefix(3)) { item in
                    HStack(spacing: 10) {
                        Circle()
                            .fill((period == nil ? Theme.accent : Theme.danger).opacity(0.7))
                            .frame(width: 6, height: 6)
                        Text(item.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(period == nil
                             ? item.targetText
                             : "\(max(2, item.sets - 1)) 组 × \(item.displayReps)")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if day.exercises.count > 3 {
                    Text("还有 \(day.exercises.count - 3) 个动作")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button(period == nil ? "开始训练" : "开始经期轻量训练") {
                showCompose = true
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("下一步可调整动作顺序、组数和重量")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .card()
    }

    private func restCard(plan: TrainingPlan, period: PeriodDay?) -> some View {
        let currentDays = plan.weekDays(in: store.currentPlanWeek)
        let next = currentDays
            .filter { day in
                guard let date = plan.scheduledDate(for: day) else { return false }
                return date > Date()
            }
            .min { left, right in
                (plan.scheduledDate(for: left) ?? .distantFuture) < (plan.scheduledDate(for: right) ?? .distantFuture)
            }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: period?.mode == .rest ? "drop.fill" : "moon.zzz.fill")
                    .foregroundStyle(period?.mode == .rest ? Theme.danger : Theme.accent)
                Text(period?.mode == .rest ? "经期休息日" : "今天休息")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("第 \(store.currentPlanWeek) 周")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if let period, period.mode == .rest {
                Text("计划中的训练已保留，但今天不要求力量训练。补铁、蛋白质和睡眠优先；腹痛明显时只做散步或舒缓拉伸。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("恢复也是训练的一部分。睡够 7 小时，蛋白质吃够，下一次训练状态会更好。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let next {
                Divider().overlay(Theme.stroke)
                Text("下一次：\(Weekday.label(next.weekday)) · \(next.title)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - 饮食

    private var nutritionCard: some View {
        let targets = DietPlanner.targets(profile: store.profile)
        let consumed = store.todayNutrition
        let remainingKcal = max(0, targets.kcal - Int(consumed.kcal))
        let remainingProtein = max(0, targets.protein - Int(consumed.protein))
        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))

        return NavigationLink {
            NutritionView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("今日饮食")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(store.profile.goalType.label)计划 · 记录饮食")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(remainingKcal)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.accent)
                        Text("kcal 剩余")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }

                ProgressView(value: ratio)
                    .tint(Theme.warning)

                HStack {
                    Text("\(Int(consumed.kcal)) / \(targets.kcal) kcal")
                    Spacer()
                    Text("蛋白质还差 \(remainingProtein)g")
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)

                HStack(spacing: 6) {
                    nutritionMetric("蛋白", consumed.protein, targets.protein)
                    nutritionMetric("碳水", consumed.carbs, targets.carbs)
                    nutritionMetric("脂肪", consumed.fat, targets.fat)
                    nutritionMetric("纤维", consumed.fiber, targets.fiber)
                }

                HStack {
                    Text("记录 / 查看饮食")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func nutritionMetric(_ title: String, _ value: Double, _ target: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
            Text("\(Int(value)) / \(target)g")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    // MARK: - 周进度与教练

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周完成")
                    .font(.headline)
                Spacer()
                Text("\(store.currentWeekSessions.count)/\(store.profile.weeklyDays) 次")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: store.weeklyCompletion)
                .tint(Theme.accent)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)

            HStack(spacing: 16) {
                stat(value: "\(store.sessions.count)", title: "累计训练")
                stat(value: "\(Int(store.totalVolume))", title: "总容量 kg")
                stat(value: "\(store.currentWeekSessions.count)", title: "本周")
            }
        }
        .card()
    }

    private func stat(value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aiReviewCard(plan: TrainingPlan) -> some View {
        let completed = store.currentWeekSessions.count
        let averageRPE = store.currentWeekAverageRPE

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 复盘")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("第 \(plan.version) 版 · \(plan.weeks) 周 · \(plan.days.count) 个训练日")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 8) {
                reviewMetric("本周完成", "\(completed)/\(max(1, store.profile.weeklyDays)) 次")
                reviewMetric("平均 RPE", averageRPE > 0 ? averageRPE.formatted(.number.precision(.fractionLength(1))) : "—")
                reviewMetric("训练容量", "\(Int(store.currentWeekVolume)) kg")
            }

            Button {
                store.requestPlanAdjustment()
            } label: {
                HStack {
                    Label("和 AI 教练聊聊，再调整计划", systemImage: "bubble.left.and.bubble.right")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private func reviewMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func inlineMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private func presentPendingWorkout() {
        guard let day = pendingWorkoutDay else { return }
        pendingWorkoutDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            workoutDay = day
        }
    }
}
