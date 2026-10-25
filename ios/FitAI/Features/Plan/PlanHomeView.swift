import SwiftUI

struct PlanHomeView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedWeek = 1
    @State private var didSelectCurrentWeek = false
    @State private var showRegenerate = false
    @State private var showAdjust = false
    @State private var showMessage = false
    @State private var showHistory = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.isGenerating {
                        generatingCard
                    } else if let plan = store.plan {
                        planContent(plan)
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("训练计划")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("计划版本历史")
                }
            }
            .sheet(isPresented: $showHistory) {
                PlanHistoryView()
            }
            .onAppear {
                syncWeekSelection()
            }
            .onChange(of: store.plan?.id) { _, _ in
                didSelectCurrentWeek = false
                syncWeekSelection()
            }
            .confirmationDialog(
                "重新生成计划？",
                isPresented: $showRegenerate,
                titleVisibility: .visible
            ) {
                Button("重新生成", role: .destructive) {
                    selectedWeek = 1
                    store.generatePlan()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前计划会被归档，历史训练记录保留。")
            }
            .confirmationDialog(
                "根据最近训练调整？",
                isPresented: $showAdjust,
                titleVisibility: .visible
            ) {
                Button("生成调整版") {
                    store.adjustPlan()
                    showMessage = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("会生成一个新版本，并替换当前计划。历史训练记录保留。")
            }
            .alert("计划已更新", isPresented: $showMessage) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(store.toast ?? "")
            }
        }
    }

    // MARK: - 内容

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

    @ViewBuilder
    private func planContent(_ plan: TrainingPlan) -> some View {
        headerCard(plan)

        weekSelector(plan)

        ForEach(plan.weekDays(in: selectedWeek)) { day in
            NavigationLink {
                PlanEditorView(day: day)
            } label: {
                dayCard(day, in: plan)
            }
            .buttonStyle(.plain)
        }

        VStack(alignment: .leading, spacing: 8) {
            Label("计划可编辑", systemImage: "hand.tap")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text("点任意训练日可以换动作、改组数。AI 会记住你的修改，下一次复盘时参考。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            if store.useEquipmentLibraryForPlans && !store.equipmentLibrary.isEmpty {
                Text("已启用器械库：\(store.equipmentLibrary.count) 件，生成计划时优先使用。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func headerCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前计划")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                Spacer()
                Text("v\(plan.version)")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(plan.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text("\(plan.weeks) 周 · \(plan.firstWeek.count) 练/周 · 当前第 \(store.currentPlanWeek) 周")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 10) {
                Button {
                    if store.currentWeekSessions.isEmpty {
                        store.toast = "还没有训练记录，先完成一次训练再让 AI 调整。"
                        showMessage = true
                    } else {
                        showAdjust = true
                    }
                } label: {
                    Label("AI 调整", systemImage: "wand.and.stars")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    showRegenerate = true
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    private func weekSelector(_ plan: TrainingPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...max(1, plan.weeks), id: \.self) { week in
                    Button {
                        selectedWeek = week
                    } label: {
                        VStack(spacing: 1) {
                            Text("第 \(week) 周")
                                .font(.footnote.weight(.semibold))
                            if week == store.currentPlanWeek {
                                Text("本周")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundStyle(selectedWeek == week ? Color.black : Theme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(
                                selectedWeek == week ? Theme.accent : Theme.surfaceStrong
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func syncWeekSelection() {
        guard !didSelectCurrentWeek else { return }
        selectedWeek = store.currentPlanWeek
        didSelectCurrentWeek = true
    }

    private func dayCard(_ day: PlanDay, in plan: TrainingPlan) -> some View {
        let date = plan.date(week: day.weekIndex, weekday: day.weekday)
        let completed = date.map { dayDate in
            store.sessions.contains { session in
                Calendar.current.isDate(session.date, inSameDayAs: dayDate)
                    && session.dayTitle == day.title
            }
        } ?? false

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(Weekday.label(day.weekday)) · \(day.title)")
                            .font(.headline)
                            .foregroundStyle(.white)

                        if let date, Calendar.current.isDateInToday(date) {
                            Text("今天")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.accent, in: Capsule())
                        }
                    }

                    Text(date.map {
                        "\($0.formatted(.dateTime.month().day())) · \(day.focusText)"
                    } ?? day.focusText)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }

            VStack(spacing: 7) {
                ForEach(day.exercises.prefix(4)) { item in
                    HStack {
                        Text(item.displayName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(item.targetText)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if day.exercises.count > 4 {
                    Text("还有 \(day.exercises.count - 4) 个动作")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .card()
    }
}

struct PlanHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
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
            .background(Theme.background.ignoresSafeArea())
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
