import SwiftUI

struct AddFoodView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State var meal: MealType
    @State var query = ""
    @State var selected: FoodItem?
    @State var grams: Double = 100
    @State var showCustomFood = false
    @State var customInitialName = ""
    @State var addedFoods: [String] = []

    init(initialMeal: MealType, date: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
        _meal = State(initialValue: initialMeal)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [FoodItem] {
        Array(FoodLibrary.search(query, custom: store.customFoods).prefix(30))
    }

    private var externalFoods: [FoodItem] {
        Array(
            (store.customFoods + FoodLibrary.all)
                .filter { $0.category == "外食" }
                .prefix(8)
        )
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

                    if !addedFoods.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("已记录 \(addedFoods.count) 种食物", systemImage: "checkmark.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.cobalt)
                            Text(addedFoods.joined(separator: "、"))
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 12)
                    }

                    TextField("搜索食物，例如：螺蛳粉、奶茶、鸡胸肉", text: $query)
                        .onChange(of: query) { _, value in
                            if value.count > 60 {
                                query = String(value.prefix(60))
                            }
                        }
                        .padding(12)
                        .background(
                            Theme.ink.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    if let food = selected {
                        selectedCard(food)
                    } else {
                        if trimmedQuery.isEmpty {
                            if !store.favoriteFoods.isEmpty {
                                foodSection("收藏", foods: store.favoriteFoods)
                            }
                            let recents = store.recentFoodItems()
                            if !recents.isEmpty {
                                foodSection("最近记录", foods: recents)
                            }
                            if !externalFoods.isEmpty {
                                foodSection("外食 / 聚餐", foods: externalFoods)
                            }
                        }

                        foodSection(
                            trimmedQuery.isEmpty ? "食物库" : "搜索结果",
                            foods: results
                        )

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
                if addedFoods.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .keyboardDoneToolbar()
            .sheet(isPresented: $showCustomFood) {
                CustomFoodEntryView(initialName: customInitialName) { food in
                    selected = food
                    grams = food.servingGrams
                }
            }
        }
    }

    private func foodSection(_ title: String, foods: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppType.micro.weight(.bold))
                .foregroundStyle(Theme.tertiaryText)
                .textCase(.uppercase)

            ForEach(foods) { food in
                foodRow(food)
            }
        }
    }

    private func foodRow(_ food: FoodItem) -> some View {
        HStack(spacing: 4) {
            Button {
                selected = food
                grams = food.servingGrams
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(food.name)
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                        Text("\(food.category) · 每 100g")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(food.kcal)) kcal")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                        Text("P\(Int(food.protein)) C\(Int(food.carbs)) F\(Int(food.fat))")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Theme.cobalt)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.select()
                store.toggleFavoriteFood(food)
            } label: {
                Image(systemName: store.isFavoriteFood(food) ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(
                        store.isFavoriteFood(food) ? Theme.warning : Theme.tertiaryText
                    )
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                store.isFavoriteFood(food) ? "取消收藏 \(food.name)" : "收藏 \(food.name)"
            )
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func selectedCard(_ food: FoodItem) -> some View {
        let factor = grams / 100

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(food.name)
                        .font(AppType.headline)
                    Text(
                        food.defaultGrams.map {
                            "常用份量约 \(Int($0))g · 每 100g \(Int(food.kcal)) kcal"
                        } ?? "每 100g · \(Int(food.kcal)) kcal"
                    )
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button("重新选择") {
                    selected = nil
                }
                .font(AppType.caption)
                .foregroundStyle(Theme.cobalt)
            }

            Stepper(value: $grams, in: 10...2000, step: 10) {
                HStack {
                    Text("份量")
                    Spacer()
                    Text("\(Int(grams)) g")
                        .foregroundStyle(Theme.ink)
                }
            }

            HStack(spacing: 10) {
                selectedMetric("\(Int(food.kcal * factor))", "kcal", Theme.cobalt)
                selectedMetric("\(Int(food.protein * factor))g", "蛋白质", Theme.primary)
                selectedMetric("\(Int(food.carbs * factor))g", "碳水", Theme.secondary)
                selectedMetric("\(Int(food.fat * factor))g", "脂肪", Theme.primary)
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
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add(_ food: FoodItem) {
        let factor = grams / 100
        store.addFoodLog(
            FoodLog(
                date: date,
                meal: meal,
                foodName: food.name,
                grams: grams,
                kcal: food.kcal * factor,
                protein: food.protein * factor,
                carbs: food.carbs * factor,
                fat: food.fat * factor,
                fiber: food.fiberPer100g * factor
            )
        )
        Haptics.success()
        withAnimation(Motion.quick) {
            addedFoods.append("\(meal.label) · \(food.name) \(Int(grams))g")
        }
        selected = nil
        query = ""
        grams = 100
    }
}
