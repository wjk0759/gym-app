import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(AppStore.self) private var store

    @State private var showAlert = false
    @State private var message = ""
    @State private var isOpening = false
    @State private var showAddFood = false
    @State private var selectedMeal: MealType = .breakfast

    private var targets: NutritionTargets {
        DietPlanner.targets(profile: store.profile)
    }

    private var meals: [MealSuggestion] {
        DietPlanner.meals(profile: store.profile)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
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
        .background(Theme.background.ignoresSafeArea())
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    selectedMeal = .breakfast
                    showAddFood = true
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                ForEach(MealType.allCases) { meal in
                    mealLogSection(meal)
                }

                Button {
                    selectedMeal = .breakfast
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
                        store.removeFoodLog(log.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(Theme.danger.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var suggestionHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("建议餐单")
                .font(.headline)
            Text("按目标热量估算，可以替换成同类食物。")
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
                Label(isOpening ? "正在打开…" : "在美团找轻食", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isOpening)

            Text(store.useRemoteAI
                 ? "当前为远程模式：需要后端配置美团联盟链接。"
                 : "当前为本地模式：先在「我的 → AI 服务」打开远程模式，并配置联盟链接。")
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
            message = "美团入口依赖后端联盟链接。请先在「我的 → AI 服务」打开远程模式，并在后端 .env 里配置 MEITUAN_DEEPLINK_BASE。"
            showAlert = true
            return
        }

        isOpening = true
        Task { @MainActor in
            do {
                if let url = try await APIClient.shared.meituanLink(keyword: "轻食") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    message = "后端没有返回可用的美团链接。"
                    showAlert = true
                }
            } catch {
                message = "美团联盟未配置或后端不可用。上线前需要企业资质并申请 CPS 权限。"
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

    init(initialMeal: MealType) {
        _meal = State(initialValue: initialMeal)
    }

    private var results: [FoodItem] {
        Array(FoodLibrary.search(query).prefix(20))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("餐次", selection: $meal) {
                        ForEach(MealType.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("搜索食物，例如：鸡胸肉、米饭", text: $query)
                        .padding(12)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    if let food = selected {
                        selectedCard(food)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(results) { food in
                                Button {
                                    selected = food
                                    grams = 100
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
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("记录食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
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
                    Text("每 100g · \(Int(food.kcal)) kcal")
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

            Stepper(value: $grams, in: 10...500, step: 10) {
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
