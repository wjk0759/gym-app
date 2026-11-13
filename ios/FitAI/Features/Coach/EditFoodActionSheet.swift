import SwiftUI

/// Adjust the estimated grams of a coach food card before confirming. The
/// original per-100g density is preserved, so macros scale with the portion.
struct EditFoodActionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let action: AgentAction

    @State private var items: [AgentFoodItem]

    init(action: AgentAction) {
        self.action = action
        _items = State(initialValue: action.payload?.items ?? [])
    }

    private var totals: (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        items.reduce(
            into: (kcal: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0)
        ) { total, item in
            total.kcal += item.kcal
            total.protein += item.proteinG
            total.carbs += item.carbsG
            total.fat += item.fatG
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADJUST / 调整份量")
                            .font(AppType.overline)
                            .tracking(1.4)
                            .foregroundStyle(Theme.cobalt)
                        Text("确认前先改估算")
                            .font(AppType.title)
                            .foregroundStyle(Theme.ink)
                        Text("调整只会修改这张确认卡；点“确认并执行”后才会写入今日饮食。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(items.indices, id: \.self) { index in
                        foodCard(index)
                    }

                    HStack(spacing: 6) {
                        Text("合计")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(Int(totals.kcal)) kcal")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.cobalt)
                    }
                    .card()

                    Button("保存份量") {
                        store.updateAgentFoodItems(actionID: action.id, items: items)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(items.isEmpty)
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("调整饮食估算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func foodCard(_ index: Int) -> some View {
        let item = items[index]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int(item.kcal)) kcal")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)
            }

            Stepper(
                value: Binding(
                    get: { items[index].grams },
                    set: { newValue in
                        items[index] = scale(items[index], to: newValue)
                    }
                ),
                in: 10...2000,
                step: 10
            ) {
                HStack {
                    Text("份量")
                    Spacer()
                    Text("\(Int(item.grams)) g")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                }
            }

            HStack(spacing: 10) {
                macro("蛋白", item.proteinG)
                macro("碳水", item.carbsG)
                macro("脂肪", item.fatG)
            }
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func macro(_ title: String, _ value: Double) -> some View {
        HStack(spacing: 3) {
            Text(title)
            Text("\(Int(value))g")
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func scale(_ item: AgentFoodItem, to grams: Double) -> AgentFoodItem {
        let safeGrams = max(1, item.grams)
        let factor = max(0, grams) / safeGrams
        return AgentFoodItem(
            name: item.name,
            portion: "\(Int(grams))g",
            grams: grams,
            kcal: item.kcal * factor,
            proteinG: item.proteinG * factor,
            carbsG: item.carbsG * factor,
            fatG: item.fatG * factor,
            confidence: item.confidence
        )
    }
}
