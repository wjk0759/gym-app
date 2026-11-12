import SwiftUI

struct NutritionView: View {
    @Environment(AppStore.self) var store

    let date: Date

    @State var showAlert = false
    @State var message = ""
    @State var showAddFood = false
    @State var showFoodPhoto = false
    @State var showWeekPlan = false
    @State var selectedMeal: MealType = .breakfast
    @State var pendingFoodDelete: FoodLog?
    @State var editingFoodLog: FoodLog?
    @State var aiMeals: [MealSuggestion]?
    @State var aiPlanNote = ""
    @State var serverTargets: NutritionTargets?
    @State var pendingPlanGenerationKey: String?
    @State var isGeneratingPlan = false
    @State var swappingMeal: MealType?
    @State var lastSwappedMeal: MealType?
    @State var mode: NutritionMode = .plan

    enum NutritionMode: String, CaseIterable, Identifiable {
        case plan
        case log

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plan: return "定制食谱"
            case .log: return "我的记录"
            }
        }

        var subtitle: String {
            switch self {
            case .plan: return "按目标排餐"
            case .log: return "吃过什么"
            }
        }
    }

    init(date: Date = Date()) {
        self.date = Calendar.current.startOfDay(for: date)
    }

    struct DayLogsSnapshot {
        let logs: [FoodLog]
        let totals: NutritionTotals
        let byMeal: [MealType: [FoodLog]]
    }

    var targets: NutritionTargets {
        serverTargets ?? DietPlanner.targets(profile: store.profile)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var daySnapshot: DayLogsSnapshot {
        let dayStart = FitnessDate.calendar.startOfDay(for: date)
        let logs = store.foodLogs.filter {
            FitnessDate.calendar.startOfDay(for: $0.date) == dayStart
        }
        let totals = logs.reduce(into: NutritionTotals()) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
            total.fiber += log.fiber ?? 0
        }
        return DayLogsSnapshot(
            logs: logs,
            totals: totals,
            byMeal: Dictionary(grouping: logs, by: \.meal)
        )
    }

    var meals: [MealSuggestion] {
        aiMeals ?? DietPlanner.meals(profile: store.profile)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dateString: String {
        Self.dateFormatter.string(from: date)
    }

    private func applyServerTargets(_ remote: RemoteDietPlan) {
        applyTargets(remote.targets)
    }

    private func applyTargets(_ values: RemoteDietPlan.Targets?) {
        guard let values,
              let kcal = values.targetKcal,
              let protein = values.proteinG,
              let carbs = values.carbG,
              let fat = values.fatG else {
            return
        }
        let base = DietPlanner.targets(profile: store.profile)
        serverTargets = NutritionTargets(
            bmr: base.bmr,
            tdee: base.tdee,
            kcal: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: base.fiber
        )
    }

    @MainActor
    func loadTargets() async {
        guard let response = try? await NutritionService().fetchTargets(
            dateString: dateString
        ) else { return }
        applyTargets(response.targets)
    }

    private func suggestions(from plan: RemoteDietPlan) -> [MealSuggestion] {
        plan.meals.map {
            MealSuggestion(
                name: $0.name,
                kcal: $0.kcal,
                items: $0.items,
                meal: MealType(rawValue: $0.meal) ?? .breakfast,
                protein: $0.proteinG ?? 0,
                carbs: $0.carbG ?? 0,
                fat: $0.fatG ?? 0
            )
        }
    }

    @MainActor
    func loadSavedPlan() async {
        do {
            guard let plan = try await NutritionService().fetchSavedPlan(
                dateString: dateString
            ), !plan.meals.isEmpty else {
                aiMeals = nil
                return
            }
            aiMeals = suggestions(from: plan)
            aiPlanNote = plan.note ?? ""
            applyServerTargets(plan)
        } catch {
            // Keep the existing plan when the failure is network-related; only
            // a 404 (handled as nil above) means the day has no saved plan.
        }
    }

    @MainActor
    func swapPlanMeal(_ suggestion: MealSuggestion) async {
        guard swappingMeal == nil else { return }
        guard aiMeals != nil else {
            message = "当前是本地参考餐单，先生成一周饮食计划再换餐。"
            showAlert = true
            return
        }
        swappingMeal = suggestion.meal
        defer { swappingMeal = nil }
        do {
            let plan = try await NutritionService().swapMeal(
                dateString: dateString,
                meal: suggestion.meal
            )
            aiMeals = suggestions(from: plan)
            applyServerTargets(plan)
            lastSwappedMeal = suggestion.meal
            Haptics.success()
        } catch let error as APIError where error.statusCode == 404 {
            message = "这一天还没有保存的饮食计划，先生成计划再换餐。"
            showAlert = true
        } catch {
            message = "换餐失败，请稍后重试。"
            showAlert = true
        }
    }

    @MainActor
    func undoPlanMealSwap(_ suggestion: MealSuggestion) async {
        guard swappingMeal == nil else { return }
        swappingMeal = suggestion.meal
        defer { swappingMeal = nil }
        do {
            let plan = try await NutritionService().undoSwapMeal(
                dateString: dateString,
                meal: suggestion.meal
            )
            aiMeals = suggestions(from: plan)
            applyServerTargets(plan)
            lastSwappedMeal = nil
            Haptics.success()
        } catch let error as APIError where error.statusCode == 404 {
            message = "没有可以撤销的换餐。"
            showAlert = true
        } catch {
            message = "撤销失败，请稍后重试。"
            showAlert = true
        }
    }

    /// One tap logs the whole planned meal using the server's per-meal macro
    /// estimate. The soft link lets the log show it came from the plan and
    /// keeps a second tap from adding the same meal twice.
    func logPlannedMeal(_ suggestion: MealSuggestion) {
        let logged = store.logPlannedMeal(
            date: date,
            meal: suggestion.meal,
            name: suggestion.name,
            kcal: Double(suggestion.kcal),
            protein: suggestion.protein,
            carbs: suggestion.carbs,
            fat: suggestion.fat,
            fiber: suggestion.fiber
        )
        if logged {
            Haptics.success()
        }
    }

    @MainActor
    func generateAIPlan() async {
        guard !isGeneratingPlan else { return }
        guard store.access.policy.canGenerateMealPlan else {
            store.requestPro(.mealPlan)
            return
        }
        guard store.useRemoteAI else {
            message = "已在设置中关闭远程 AI。打开后可以生成 AI 饮食计划。"
            showAlert = true
            return
        }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }
        let idempotencyKey = pendingPlanGenerationKey ?? UUID().uuidString
        pendingPlanGenerationKey = idempotencyKey
        do {
            let plan = try await NutritionService().fetchPlan(
                dateString: dateString,
                idempotencyKey: idempotencyKey
            )
            pendingPlanGenerationKey = nil
            guard !plan.meals.isEmpty else { return }
            aiMeals = suggestions(from: plan)
            aiPlanNote = plan.note ?? ""
            applyServerTargets(plan)
        } catch let error as APIError where error.isProRequired {
            await store.refreshAccess()
            store.requestPro(.mealPlan)
        } catch {
            message = "AI 饮食计划生成失败，先使用本地餐单参考。"
            showAlert = true
        }
    }

    var body: some View {
        let nutritionTargets = targets
        let snapshot = daySnapshot

        return AppScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(snapshot: snapshot, targets: nutritionTargets)
                modePicker
                toolRow
                macroStrip(snapshot: snapshot, targets: nutritionTargets)

                if mode == .plan {
                    planHeader(snapshot: snapshot)
                    ForEach(meals.indices, id: \.self) { index in
                        let meal = meals[index]
                        planMealPage(meal, index: index, logs: snapshot.byMeal[mealType(for: meal)] ?? [])
                    }
                } else {
                    logHeader(snapshot: snapshot)
                    ForEach(MealType.allCases) { meal in
                        logMealPage(meal, logs: snapshot.byMeal[meal] ?? [])
                    }
                    addFoodButton
                }

                disclaimer
            }
            .appPagePadding()
            .appReadableContent()
            .appPageTopPadding()
            .padding(.bottom, 32)
        }
        .background(AppBackground())
        .navigationTitle(isToday ? "今日饮食" : "饮食记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("提示", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodView(initialMeal: selectedMeal, date: date)
        }
        .sheet(isPresented: $showFoodPhoto) {
            FoodPhotoAnalysisView(date: date)
        }
        .sheet(item: $editingFoodLog) { log in
            EditFoodLogSheet(log: log)
        }
        .sheet(isPresented: $showWeekPlan, onDismiss: {
            Task {
                await loadTargets()
                await loadSavedPlan()
            }
        }) {
            WeekDietPlanView()
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
        .task(id: dateString) {
            lastSwappedMeal = nil
            await loadTargets()
            await loadSavedPlan()
        }
    }

    var suggestedMeal: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<21: return .dinner
        default: return .snack
        }
    }
}
