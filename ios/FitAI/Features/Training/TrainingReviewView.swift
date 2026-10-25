import SwiftUI

/// 训练复盘：只负责呈现证据、解释调整，并决定是否生成下一版计划。
struct TrainingReviewView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedSession: WorkoutSession?
    @State private var showAdjustConfirm = false
    @State private var showAdjustResult = false
    @State private var showNoData = false

    init() {}

    private var completed: Int {
        store.currentWeekSessions.count
    }

    private var preview: PlanGenerator.Adjustment {
        store.planAdjustmentPreview
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                intro
                statsCard

                if let plan = store.plan {
                    adjustmentCard(plan: plan)
                    recentCard
                } else {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "先生成训练计划",
                        message: "有计划和训练记录后，复盘才会给出具体的组数或重量调整。"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
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
            Text("\(preview.detail)\n\n会生成一个新版本，当前计划会被替换；旧版本和训练记录都会保留。")
        }
        .alert("计划已更新", isPresented: $showAdjustResult) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(store.toast ?? "")
        }
        .alert("还不能复盘", isPresented: $showNoData) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("先完成一次训练，复盘才有完成率和 RPE 可参考。")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Theme.accent)
                Text("本周复盘")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Text("复盘不是给你打分，而是根据本周实际完成情况，决定下一版训练是加量、减量还是保持。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周数据")
                    .font(.headline)
                Spacer()
                Text("\(completed)/\(max(1, store.profile.weeklyDays)) 次")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            ProgressView(
                value: min(1, Double(completed) / Double(max(1, store.profile.weeklyDays)))
            )
            .tint(Theme.accent)

            HStack(spacing: 8) {
                reviewMetric(
                    "完成率",
                    "\(Int(store.weeklyCompletion * 100))%"
                )
                reviewMetric(
                    "平均 RPE",
                    store.currentWeekAverageRPE > 0
                        ? store.currentWeekAverageRPE.formatted(.number.precision(.fractionLength(1)))
                        : "—"
                )
                reviewMetric(
                    "训练容量",
                    "\(Int(store.currentWeekVolume)) kg"
                )
            }
        }
        .card()
    }

    private func adjustmentCard(plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("下版建议")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(preview.headline)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("当前 v\(plan.version)")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(completed == 0 ? "完成率、平均 RPE 与训练容量会一起参与判断。" : preview.detail)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("复盘会生成新版本；旧版本可以在计划历史里恢复，训练记录不会被覆盖。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                if store.currentWeekSessions.isEmpty {
                    showNoData = true
                } else {
                    showAdjustConfirm = true
                }
            } label: {
                Label("生成调整版", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本周训练记录")
                    .font(.headline)
                Spacer()
                Text("\(store.currentWeekSessions.count) 次")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if store.currentWeekSessions.isEmpty {
                Text("本周还没有训练记录。完成一次训练后，这里会出现可点击的明细。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(store.currentWeekSessions.prefix(5)) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.dayTitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(session.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(session.volume)) kg")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("\(session.durationMinutes) 分钟")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
            }
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
