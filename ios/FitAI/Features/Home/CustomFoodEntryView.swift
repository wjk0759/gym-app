/// 记录“食物库里没有的东西”。不需要用户知道每 100g 的营养值，按实际吃的一份填写即可。
import SwiftUI

struct CustomFoodEntryView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss

    @State var name: String
    @State var portion = "100"
    @State var kcal = ""
    @State var protein = ""
    @State var carbs = ""
    @State var fat = ""
    @State var errorMessage: String?

    private let onSave: (FoodItem) -> Void

    init(initialName: String, onSave: @escaping (FoodItem) -> Void) {
        _name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("按你实际吃的一份填写")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        Text("不知道蛋白质、碳水或脂肪可以留空。先记下热量也可以，之后还能补充。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("食物")
                            .font(AppType.headline)
                        field("名称", text: $name, placeholder: "例如：螺蛳粉")
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("这一份")
                            .font(AppType.headline)
                        field("重量（g）", text: $portion, placeholder: "例如：600", keyboard: .decimalPad)
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("这一份的营养素")
                                .font(AppType.headline)
                            Spacer()
                            Text("可选")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        field("热量（kcal）", text: $kcal, placeholder: "例如：750", keyboard: .decimalPad)
                        HStack(spacing: 8) {
                            field("蛋白质（g）", text: $protein, placeholder: "可选", keyboard: .decimalPad)
                            field("碳水（g）", text: $carbs, placeholder: "可选", keyboard: .decimalPad)
                            field("脂肪（g）", text: $fat, placeholder: "可选", keyboard: .decimalPad)
                        }
                    }
                    .card(padding: 16)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.danger)
                    }

                    Button("保存并选择") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("手动添加食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .padding(11)
                .background(
                    Theme.ink.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "先填写食物名称。"
            return
        }
        guard let portionValue = number(portion), portionValue > 0 else {
            errorMessage = "这一份的重量需要大于 0。"
            return
        }
        guard let energy = number(kcal), energy >= 0 else {
            errorMessage = "先填写这一份的热量，哪怕只是估算也可以。"
            return
        }

        let factor = 100 / portionValue
        let item = FoodItem(
            name: cleanName,
            category: "自定义",
            kcal: energy * factor,
            protein: (number(protein) ?? 0) * factor,
            carbs: (number(carbs) ?? 0) * factor,
            fat: (number(fat) ?? 0) * factor,
            defaultGrams: portionValue
        )
        store.addCustomFood(item)
        onSave(item)
        dismiss()
    }

    private func number(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}
