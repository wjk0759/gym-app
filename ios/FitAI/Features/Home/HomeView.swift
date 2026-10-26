import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store

    @State private var showCompose = false
    @State private var pendingWorkoutDay: PlanDay?
    @State private var workoutDay: PlanDay?
    @State private var showAdjustConfirm = false
    @State private var showAdjustResult = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    greeting

                    if store.isGenerating {
                        generatingCard
                    } else if let plan = store.plan {
                        todayCard(plan: plan)
                    } else {
                        noPlanCard
                    }

                    if let plan = store.plan {
                        aiReviewCard(plan: plan)
                    }

                    weekCard

                    nutritionCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(
                isPresented: $showCompose,
                onDismiss: presentPendingWorkout
            ) {
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
                WorkoutSessionView(day: day)
            }
            .confirmationDialog(
                "用本周训练复盘并调整？",
                isPresented: $showAdjustConfirm,
                titleVisibility: .visible
            ) {
                Button("生成调整版") {
                    store.adjustPlan()
                    showAdjustResult = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("\(store.planAdjustmentPreview.detail)\n\n会生成一个新版本，当前计划会被替换，历史版本保留。")
            }
            .alert("计划已调整", isPresented: $showAdjustResult) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(store.toast ?? "")
            }
        }
    }

    // MARK: - 顶部问候

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

    // MARK: - 今日

    private var generatingCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Theme.accent)
                .scaleEffect(1.2)
            Text("正在为你编排 4 周计划…")
                .font(.headline)
            Text("根据目标、器械和每周 \(store.profile.weeklyDays) 天的时间安排")
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

    @ViewBuilder
    private func todayCard(plan: TrainingPlan) -> some View {
        if store.isPlanFinished {
            finishedPlanCard
        } else if let day = store.todayDay {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("今日训练")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
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

                HStack(spacing: 24) {
                    inlineMetric(title: "动作", value: "\(day.exercises.count) 个")
                    inlineMetric(title: "预计", value: "\(day.estimatedMinutes) 分钟")
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(day.exercises.prefix(3)) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Theme.accent.opacity(0.7))
                                .frame(width: 6, height: 6)
                            Text(item.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(item.targetText)
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

                Button("开始训练") {
                    showCompose = true
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("下一步可调整动作顺序、组数和重量")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .card()
        } else {
            restCard(plan: plan)
        }
    }

    private func presentPendingWorkout() {
        guard let day = pendingWorkoutDay else { return }
        pendingWorkoutDay = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            workoutDay = day
        }
    }

    private func restCard(plan: TrainingPlan) -> some View {
        let currentDays = plan.weekDays(in: store.currentPlanWeek)
        let next = currentDays
            .filter { $0.weekday > Weekday.today }
            .min { $0.weekday < $1.weekday }
            ?? plan.weekDays(in: min(plan.weeks, store.currentPlanWeek + 1)).first

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(Theme.accent)
                Text("今天休息")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("恢复也是训练的一部分。睡够 7 小时，蛋白质吃够。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
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

    private var finishedPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                Text("这一阶段完成了")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("4 周计划已结束。现在可以结合完成率、RPE 和容量，生成下一阶段计划；旧计划会保留在版本历史里。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("生成下一阶段计划") {
                store.generatePlan()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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

    // MARK: - 周进度

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

    // MARK: - AI 复盘

    private var nutritionCard: some View {
        let targets = DietPlanner.targets(profile: store.profile)
        let consumed = store.todayNutrition
        let remainingKcal = max(0, targets.kcal - Int(consumed.kcal))
        let remainingProtein = max(0, targets.protein - Int(consumed.protein))

        return NavigationLink {
            NutritionView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日饮食")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(remainingKcal > 0
                         ? "还可摄入 \(remainingKcal) kcal · 蛋白质还差 \(remainingProtein)g"
                         : "已达到今日热量目标 · 蛋白质还差 \(remainingProtein)g")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private func aiReviewCard(plan: TrainingPlan) -> some View {
        let preview = store.planAdjustmentPreview
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

            Text(completed == 0 ? "先记录一次训练，复盘才有数据。" : "这次复盘：\(preview.headline)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            Text(completed == 0 ? "完成率、平均 RPE 与训练容量会一起参与判断。" : preview.detail)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if store.currentWeekSessions.isEmpty {
                    store.toast = "最近 7 天还没有训练记录。先完成一次训练，AI 才有数据可复盘。"
                    showAdjustResult = true
                } else {
                    showAdjustConfirm = true
                }
            } label: {
                HStack {
                    Label("让 AI 复盘并调整", systemImage: "wand.and.stars")
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
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

}
