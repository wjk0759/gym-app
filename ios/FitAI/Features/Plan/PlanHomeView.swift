import SwiftUI

struct PlanHomeView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedWeek = 1
    @State private var showRegenerate = false
    @State private var showAdjust = false
    @State private var showMessage = false

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
                dayCard(day)
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

            Text("\(plan.weeks) 周 · \(plan.firstWeek.count) 练/周 · \(plan.days.count) 个训练日")
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
                        Text("第 \(week) 周")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(selectedWeek == week ? Color.black : Theme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
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

    private func dayCard(_ day: PlanDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Weekday.label(day.weekday)) · \(day.title)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(day.focusText)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
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
