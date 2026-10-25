import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store

    /// 嵌入训练 Tab 时由 TrainingHubView 提供导航标题和底部 Tab。
    var embedded = false

    @State private var showWorkout = false
    @State private var selectedSession: WorkoutSession?

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .navigationTitle("今日")
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                greeting

                if store.isGenerating {
                    generatingCard
                } else if let plan = store.plan {
                    todayCard(plan: plan)
                } else {
                    noPlanCard
                }

                weekCard

                nutritionCard

                recentCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .fullScreenCover(isPresented: $showWorkout) {
            if let day = store.todayDay {
                WorkoutSessionView(day: day)
            }
        }
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }

    // MARK: - 顶部问候

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(timeGreeting)，\(store.profile.nickname)")
                .font(.title2.weight(.bold))
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
                    showWorkout = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .card()
        } else {
            restCard(plan: plan)
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

    // MARK: - 最近训练

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近训练")
                    .font(.headline)
                Spacer()
                if !store.sessions.isEmpty {
                    Text("共 \(store.sessions.count) 次")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            if store.sessions.isEmpty {
                Text("完成第一次训练后，这里会显示记录和容量趋势。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 6)
            } else {
                ForEach(store.sessions.prefix(3)) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.dayTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                                .padding(.leading, 2)
                        }
                    }
                    .buttonStyle(.plain)
                    if session.id != store.sessions.prefix(3).last?.id {
                        Divider().overlay(Theme.stroke)
                    }
                }
            }
        }
        .card()
    }
}
