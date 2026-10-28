import SwiftUI

/// 训练方案库：把“全身 / 推拉腿 / 部位五分”变成可执行的计划分化。
struct TrainingLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pendingSplit: SplitType?
    @State private var showConfirm = false

    private struct SplitCard: Identifiable {
        let split: SplitType
        let symbol: String
        let eyebrow: String
        let recommended: String
        let bullets: [String]
        var id: String { split.id }
    }

    private let cards: [SplitCard] = [
        SplitCard(
            split: .one,
            symbol: "figure.strengthtraining.functional",
            eyebrow: "新手先练全身",
            recommended: "每周 2–3 练",
            bullets: ["每次覆盖胸背腿", "动作少，恢复快", "出差也能用徒手完成"]
        ),
        SplitCard(
            split: .three,
            symbol: "arrow.triangle.2.circlepath",
            eyebrow: "推 / 拉 / 腿循环",
            recommended: "每周 3–5 练",
            bullets: ["训练日更聚焦", "同一肌群有恢复窗口", "适合有基础后进阶"]
        ),
        SplitCard(
            split: .five,
            symbol: "square.grid.2x2.fill",
            eyebrow: "部位五分",
            recommended: "每周 4–7 练",
            bullets: ["胸 / 背 / 腿 / 肩 / 手臂", "单次训练量集中", "需要稳定出勤和恢复"]
        )
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(cards) { card in
                        splitCard(card)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("计划会按你的器械和时间生成", systemImage: "wand.and.stars")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Text("当前器械：\(store.profile.equipment.map(\.label).sorted().joined(separator: " / "))\n每周 \(store.profile.weeklyDays) 练 · 每次 \(store.profile.sessionMinutes) 分钟")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(padding: 14)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("训练方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog(
                "用这个分化重新生成计划？",
                isPresented: $showConfirm,
                titleVisibility: .visible
            ) {
                if let pendingSplit {
                    Button("用 \(pendingSplit.title) 重新生成") {
                        apply(pendingSplit)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("当前计划会归档，历史训练记录保留。生成后可以在记录页调整日期。")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("练法选明白，\n进馆不发呆。")
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("先选适合出勤频率的分化，再让教练按你的器械和时间排动作。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func splitCard(_ card: SplitCard) -> some View {
        let selected = store.profile.split == card.split
        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: card.symbol)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(selected ? Color.black : Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(
                        selected ? Theme.accent : Theme.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.eyebrow)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(card.split.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(card.split.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 4)

                if selected {
                    Text("当前")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: Capsule())
                }
            }

            HStack(spacing: 8) {
                Label(card.recommended, systemImage: "calendar")
                Text("·")
                Text("当前每周 \(store.profile.weeklyDays) 练")
            }
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(card.bullets, id: \.self) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(Theme.accent.opacity(0.8))
                            .frame(width: 4, height: 4)
                            .padding(.top, 5)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            applyButton(card, selected: selected)
        }
        .card()
    }

    @ViewBuilder
    private func applyButton(_ card: SplitCard, selected: Bool) -> some View {
        if selected {
            Button("当前使用中") {}
                .buttonStyle(SecondaryButtonStyle())
                .disabled(true)
        } else {
            Button("用这个分化生成计划") {
                Haptics.select()
                pendingSplit = card.split
                showConfirm = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.isGenerating)
        }
    }

    private func apply(_ split: SplitType) {
        store.profile.split = split
        store.toast = "正在按 \(split.title) 重新生成计划"
        store.persist()
        store.generatePlan(force: true)
        dismiss()
        store.selectedTab = 1
    }
}
