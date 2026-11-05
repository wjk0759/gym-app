import SwiftUI

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
                .appPageTopPadding()
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
