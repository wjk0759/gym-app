import SwiftUI

/// Edit an existing food log without deleting and re-adding it. The client ID
/// stays the same, so the server upsert updates the original row and cross-device
/// history keeps a single entry.
struct EditFoodLogSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let log: FoodLog

    @State private var meal: MealType
    @State private var name: String
    @State private var gramsText: String
    @State private var kcalText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var fiberText: String

    init(log: FoodLog) {
        self.log = log
        _meal = State(initialValue: log.meal)
        _name = State(initialValue: log.foodName)
        _gramsText = State(initialValue: Self.text(log.grams))
        _kcalText = State(initialValue: Self.text(log.kcal))
        _proteinText = State(initialValue: Self.text(log.protein))
        _carbsText = State(initialValue: Self.text(log.carbs))
        _fatText = State(initialValue: Self.text(log.fat))
        _fiberText = State(initialValue: Self.text(log.fiber ?? 0))
    }

    private static func text(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EDIT / 修改记录")
                            .font(AppType.overline)
                            .tracking(1.4)
                            .foregroundStyle(Theme.cobalt)
                        Text("改这一条，不会新增记录")
                            .font(AppType.title)
                            .foregroundStyle(Theme.ink)
                        Text("保存后会用同一个客户端 ID 更新服务端记录；计划餐关联会保留。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Picker("餐次", selection: $meal) {
                        ForEach(MealType.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("食物")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        TextField("食物名称", text: $name)
                            .padding(12)
                            .background(
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        numberField("份量", text: $gramsText, unit: "g")
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("营养估算")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        numberField("热量", text: $kcalText, unit: "kcal")
                        numberField("蛋白质", text: $proteinText, unit: "g")
                        numberField("碳水", text: $carbsText, unit: "g")
                        numberField("脂肪", text: $fatText, unit: "g")
                        numberField("膳食纤维", text: $fiberText, unit: "g")
                    }
                    .card()

                    if log.planDate != nil {
                        Label("这是一条计划餐记录，修改后仍保留计划关联。", systemImage: "link")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Button("保存修改") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(trimmedName.isEmpty)

                    Button("删除这条记录", role: .destructive) {
                        store.removeFoodLog(log.id)
                        dismiss()
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("修改饮食记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private func numberField(
        _ title: String,
        text: Binding<String>,
        unit: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .frame(maxWidth: 110)
            Text(unit)
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .frame(width: 34, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func save() {
        var updated = log
        updated.meal = meal
        updated.foodName = trimmedName
        updated.grams = max(0, Double(gramsText) ?? log.grams)
        updated.kcal = max(0, Double(kcalText) ?? log.kcal)
        updated.protein = max(0, Double(proteinText) ?? log.protein)
        updated.carbs = max(0, Double(carbsText) ?? log.carbs)
        updated.fat = max(0, Double(fatText) ?? log.fat)
        updated.fiber = max(0, Double(fiberText) ?? log.fiber ?? 0)
        store.updateFoodLog(updated)
        Haptics.success()
        dismiss()
    }
}
