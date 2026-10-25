import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(AppStore.self) private var store

    @State private var showAlert = false
    @State private var message = ""
    @State private var isOpening = false
    @State private var showAddFood = false
    @State private var showFoodPhoto = false
    @State private var selectedMeal: MealType = .breakfast
    @State private var pendingFoodDelete: FoodLog?

    private var targets: NutritionTargets {
        DietPlanner.targets(profile: store.profile)
    }

    private var meals: [MealSuggestion] {
        DietPlanner.meals(profile: store.profile)
    }

    var body: some View {
        AppScrollView {
            VStack(spacing: 16) {
                header
                photoFoodCard
                todayLogCard
                macroCard
                suggestionHeader

                ForEach(meals) { meal in
                    mealCard(meal)
                }

                meituanCard
                disclaimer
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(AppBackground())
        .navigationTitle("饮食计划")
        .navigationBarTitleDisplayMode(.inline)
        .alert("美团外卖", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodView(initialMeal: selectedMeal)
        }
        .sheet(isPresented: $showFoodPhoto) {
            FoodPhotoAnalysisView()
        }
        .confirmationDialog(
            "删除这条饮食记录？",
            isPresented: Binding(
                get: { pendingFoodDelete != nil },
                set: { if !$0 { pendingFoodDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingFoodDelete
        ) { log in
            Button("删除", role: .destructive) {
                store.removeFoodLog(log.id)
                pendingFoodDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingFoodDelete = nil
            }
        } message: { log in
            Text("\(log.foodName) · \(Int(log.kcal)) kcal")
        }
    }

    private var suggestedMeal: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<21: return .dinner
        default: return .snack
        }
    }

    private var photoFoodCard: some View {
        Button {
            showFoodPhoto = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text("拍照识别饮食")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("拍一餐，估算热量与三大营养素")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        let consumed = store.todayNutrition
        let remainingKcal = max(0, targets.kcal - Int(consumed.kcal))
        let remainingProtein = max(0, targets.protein - Int(consumed.protein))

        return VStack(alignment: .leading, spacing: 8) {
            Text("今日热量目标")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(targets.kcal)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("kcal")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(remainingKcal > 0
                 ? "还可摄入 \(remainingKcal) kcal · 蛋白质还差 \(remainingProtein)g"
                 : "已达到今日热量目标 · 蛋白质还差 \(remainingProtein)g")
                .font(.caption.weight(.semibold))
                .foregroundStyle(remainingKcal > 0 ? Theme.accent : Theme.warning)

            Text("按 \(store.profile.goalType.label) 目标与每周 \(store.profile.weeklyDays) 练估算。结果是一个区间，不需要精确到个位数。")
                .font(.caption)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("宏量营养素")
                .font(.headline)

            HStack(spacing: 10) {
                macro("蛋白质", "\(Int(store.todayNutrition.protein)) / \(targets.protein)g", color: Theme.accent)
                macro("碳水", "\(Int(store.todayNutrition.carbs)) / \(targets.carbs)g", color: Theme.warning)
                macro("脂肪", "\(Int(store.todayNutrition.fat)) / \(targets.fat)g", color: Color(red: 0.55, green: 0.70, blue: 0.98))
            }

            Text("BMR \(targets.bmr) kcal · 维持热量约 \(targets.tdee) kcal")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var todayLogCard: some View {
        let totals = store.todayNutrition
        let ratio = min(1.0, totals.kcal / Double(max(1, targets.kcal)))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日记录")
                    .font(.headline)
                Spacer()
                Text("\(Int(totals.kcal)) / \(targets.kcal) kcal")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: ratio)
                .tint(Theme.accent)

            if store.todayFoodLogs.isEmpty {
                Text("还没有记录。记下吃了什么，才能知道离目标还差多少。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button("记录第一餐") {
                    selectedMeal = suggestedMeal
                    showAddFood = true
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                ForEach(MealType.allCases) { meal in
                    mealLogSection(meal)
                }

                Button {
                    selectedMeal = suggestedMeal
                    showAddFood = true
                } label: {
                    Label("添加食物", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    @ViewBuilder
    private func mealLogSection(_ meal: MealType) -> some View {
        let logs = store.todayFoodLogs.filter { $0.meal == meal }
        if !logs.isEmpty {
            HStack {
                Text(meal.label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(logs.reduce(0.0) { $0 + $1.kcal })) kcal")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button {
                    selectedMeal = meal
                    showAddFood = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            ForEach(logs) { log in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.foodName)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("\(log.grams.formatted()) g")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer()
                    Text("\(Int(log.kcal)) kcal")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Button(role: .destructive) {
                        pendingFoodDelete = log
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(Theme.danger.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除 \(log.foodName)")
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var suggestionHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("建议餐单")
                .font(.headline)
            Text("按目标热量估算，只是参考；外食、奶茶也可以正常记录。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func macro(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func mealCard(_ meal: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.name)
                    .font(.headline)
                Spacer()
                Text("约 \(meal.kcal) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            ForEach(meal.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.accent.opacity(0.8))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var meituanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "takeoutbag.and.cup.and.straw")
                    .foregroundStyle(Theme.accent)
                Text("附近外卖")
                    .font(.headline)
            }

            Text("美团联盟只提供活动/搜索跳转，不提供菜品营养数据。点开后请按商家页面为准。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openMeituan()
            } label: {
                Label(isOpening ? "正在打开…" : "在美团找外卖", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isOpening || !store.useRemoteAI)

            Text(store.useRemoteAI
                 ? "外卖链接由美团联盟提供，价格与营养信息以商家页面为准。"
                 : "外卖入口正在接入，上线后可用。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var disclaimer: some View {
        Text("饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等特殊情况请咨询医生或营养师。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private func openMeituan() {
        guard store.useRemoteAI else {
            message = "外卖入口正在接入，上线后可用。"
            showAlert = true
            return
        }

        isOpening = true
        Task { @MainActor in
            do {
                if let url = try await APIClient.shared.meituanLink(keyword: "美食") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    message = "暂时没有可用的外卖链接，请稍后再试。"
                    showAlert = true
                }
            } catch {
                message = "外卖入口暂时不可用，请稍后再试。"
                showAlert = true
            }
            isOpening = false
        }
    }
}

struct AddFoodView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var meal: MealType
    @State private var query = ""
    @State private var selected: FoodItem?
    @State private var grams: Double = 100
    @State private var showCustomFood = false
    @State private var customInitialName = ""

    init(initialMeal: MealType) {
        _meal = State(initialValue: initialMeal)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [FoodItem] {
        Array(FoodLibrary.search(query, custom: store.customFoods).prefix(30))
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("餐次", selection: $meal) {
                        ForEach(MealType.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("搜索食物，例如：螺蛳粉、奶茶、鸡胸肉", text: $query)
                        .padding(12)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    Text("记录是为了了解，不是为了给食物打分。奶茶、火锅、螺蛳粉都可以记。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let food = selected {
                        selectedCard(food)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(results) { food in
                                Button {
                                    selected = food
                                    grams = food.servingGrams
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(food.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.white)
                                            Text("\(food.category) · 每 100g")
                                                .font(.caption2)
                                                .foregroundStyle(Theme.secondaryText)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Int(food.kcal)) kcal")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Theme.accent)
                                            Text("P\(Int(food.protein)) C\(Int(food.carbs)) F\(Int(food.fat))")
                                                .font(.caption2)
                                                .foregroundStyle(Theme.tertiaryText)
                                        }
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Theme.accent)
                                    }
                                    .padding(12)
                                    .background(
                                        Theme.surfaceStrong,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            customInitialName = trimmedQuery
                            showCustomFood = true
                        } label: {
                            Label(
                                trimmedQuery.isEmpty
                                    ? "找不到？手动添加食物"
                                    : "找不到？手动添加「\(trimmedQuery)」",
                                systemImage: "square.and.pencil"
                            )
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("记录食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustomFood) {
                CustomFoodEntryView(initialName: customInitialName) { food in
                    selected = food
                    grams = food.servingGrams
                }
            }
        }
    }

    private func selectedCard(_ food: FoodItem) -> some View {
        let factor = grams / 100

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(.headline)
                    Text(
                        food.defaultGrams.map {
                            "常用份量约 \(Int($0))g · 每 100g \(Int(food.kcal)) kcal"
                        } ?? "每 100g · \(Int(food.kcal)) kcal"
                    )
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button("重新选择") {
                    selected = nil
                }
                .font(.caption)
                .foregroundStyle(Theme.accent)
            }

            Stepper(value: $grams, in: 10...2000, step: 10) {
                HStack {
                    Text("份量")
                    Spacer()
                    Text("\(Int(grams)) g")
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                selectedMetric("\(Int(food.kcal * factor))", "kcal", Theme.accent)
                selectedMetric("\(Int(food.protein * factor))g", "蛋白质", Theme.accent)
                selectedMetric("\(Int(food.carbs * factor))g", "碳水", Theme.warning)
                selectedMetric("\(Int(food.fat * factor))g", "脂肪", Color(red: 0.55, green: 0.70, blue: 0.98))
            }

            Button("添加到\(meal.label)") {
                add(food)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .card()
    }

    private func selectedMetric(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add(_ food: FoodItem) {
        let factor = grams / 100
        store.addFoodLog(
            FoodLog(
                meal: meal,
                foodName: food.name,
                grams: grams,
                kcal: food.kcal * factor,
                protein: food.protein * factor,
                carbs: food.carbs * factor,
                fat: food.fat * factor
            )
        )
        dismiss()
    }
}

/// 记录“食物库里没有的东西”。不需要用户知道每 100g 的营养值，按实际吃的一份填写即可。
struct CustomFoodEntryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var portion = "100"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var errorMessage: String?

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
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("不知道蛋白质、碳水或脂肪可以留空。先记下热量也可以，之后还能补充。")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("食物")
                            .font(.headline)
                        field("名称", text: $name, placeholder: "例如：螺蛳粉")
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("这一份")
                            .font(.headline)
                        field("重量（g）", text: $portion, placeholder: "例如：600", keyboard: .decimalPad)
                        Text("如果吃的是一整碗/一整份，填整份重量。螺蛳粉通常约 500–700g。")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .card(padding: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("这一份的营养素")
                                .font(.headline)
                            Spacer()
                            Text("可选")
                                .font(.caption2)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        field("热量（kcal）", text: $kcal, placeholder: "例如：750", keyboard: .decimalPad)
                        HStack(spacing: 8) {
                            field("蛋白质（g）", text: $protein, placeholder: "可选", keyboard: .decimalPad)
                            field("碳水（g）", text: $carbs, placeholder: "可选", keyboard: .decimalPad)
                            field("脂肪（g）", text: $fat, placeholder: "可选", keyboard: .decimalPad)
                        }
                        Text("这些数值会按“这一份”换算成每 100g 保存，下次搜索这个食物时可以直接复用。")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .card(padding: 16)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                    }

                    Button("保存并选择") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("没有“好食物/坏食物”。记录只是帮你了解今天吃了什么。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
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
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .padding(11)
                .background(
                    Theme.surfaceStrong,
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
