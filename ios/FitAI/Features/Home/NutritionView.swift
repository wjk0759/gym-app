import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(AppStore.self) private var store

    let date: Date

    @State private var showAlert = false
    @State private var message = ""
    @State private var isOpening = false
    @State private var showAddFood = false
    @State private var showFoodPhoto = false
    @State private var showWeekPlan = false
    @State private var selectedMeal: MealType = .breakfast
    @State private var pendingFoodDelete: FoodLog?
    @State private var aiMeals: [MealSuggestion]?
    @State private var aiPlanNote = ""
    @State private var isGeneratingPlan = false
    @State private var mode: NutritionMode = .plan

    private enum NutritionMode: String, CaseIterable, Identifiable {
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

    private struct DayLogsSnapshot {
        let logs: [FoodLog]
        let totals: NutritionTotals
        let byMeal: [MealType: [FoodLog]]
    }

    private var targets: NutritionTargets {
        DietPlanner.targets(profile: store.profile)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var daySnapshot: DayLogsSnapshot {
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

    private var meals: [MealSuggestion] {
        aiMeals ?? DietPlanner.meals(profile: store.profile)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: date)
    }

    @MainActor
    private func generateAIPlan() async {
        guard store.canUseRemoteAI, !isGeneratingPlan else { return }
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }
        do {
            let plan = try await APIClient.shared.fetchDietPlan(dateString: dateString)
            guard !plan.meals.isEmpty else { return }
            aiMeals = plan.meals.map {
                MealSuggestion(name: $0.name, kcal: $0.kcal, items: $0.items)
            }
            aiPlanNote = plan.note ?? ""
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
                    planHeader
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

                meituanCard
                disclaimer
            }
            .appPagePadding()
            .appReadableContent()
            .padding(.bottom, 104)
        }
        .background(AppBackground())
        .overlay(alignment: .bottomTrailing) {
            CaptureFAB {
                showFoodPhoto = true
            }
            .padding(.trailing, 20)
            .padding(.bottom, 92)
        }
        .navigationTitle(isToday ? "今日饮食" : "饮食记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("美团外卖", isPresented: $showAlert) {
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
        .sheet(isPresented: $showWeekPlan) {
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

    // MARK: - Notebook layout

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(NutritionMode.allCases) { item in
                let selected = mode == item
                Button {
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        mode = item
                    }
                } label: {
                    VStack(spacing: 2) {
                        Text(item.title)
                            .font(AppType.caption.weight(.bold))
                        Text(item.subtitle)
                            .font(AppType.micro)
                            .opacity(selected ? 0.68 : 0.55)
                    }
                    .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selected ? Theme.cobalt : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))
            }
        }
        .padding(4)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 8) {
            toolTile(
                title: "拍照识别",
                detail: "估算热量",
                symbol: "camera.viewfinder",
                accent: Theme.lime
            ) {
                showFoodPhoto = true
            }
            toolTile(
                title: "本周计划",
                detail: "换饮食策略",
                symbol: "calendar.badge.clock",
                accent: Theme.cobalt
            ) {
                showWeekPlan = true
            }
        }
    }

    private func toolTile(
        title: String,
        detail: String,
        symbol: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 32, height: 32)
                    .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.98))
    }

    private func macroStrip(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let totals = snapshot.totals
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                macroPill("蛋白", value: totals.protein, target: targets.protein, color: Theme.cobalt)
                macroPill("碳水", value: totals.carbs, target: targets.carbs, color: Theme.warning)
                macroPill("脂肪", value: totals.fat, target: targets.fat, color: Theme.coral)
                macroPill("纤维", value: totals.fiber, target: targets.fiber, color: Theme.cobaltSecondary)
            }
            HStack(spacing: 6) {
                Text("BMR \(targets.bmr) kcal")
                Text("·")
                Text("维持 \(targets.tdee) kcal")
                Spacer()
                Text(mode == .plan ? "按目标排餐" : "\(snapshot.logs.count) 条记录")
            }
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func macroPill(_ title: String, value: Double, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
                    .font(AppType.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text("/ \(target)g")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(title)
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
            Capsule()
                .fill(color.opacity(0.20))
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * min(1, value / Double(max(1, target))))
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var planHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日食谱")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(aiMeals == nil ? "按目标热量估算；也可以让 AI 按档案重排。" : "AI 按你的档案、体型和目标排餐。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button {
                Task { await generateAIPlan() }
            } label: {
                if isGeneratingPlan {
                    ProgressView().controlSize(.small)
                } else {
                    Label(aiMeals == nil ? "AI 生成" : "重排", systemImage: "sparkles")
                        .font(AppType.micro.weight(.bold))
                        .foregroundStyle(Theme.cobalt)
                }
            }
            .buttonStyle(SubtlePressStyle())
            .disabled(isGeneratingPlan || !store.canUseRemoteAI)
        }
    }

    private func logHeader(snapshot: DayLogsSnapshot) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("我的记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("吃过什么就记什么，不用给食物打分。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("\(snapshot.logs.count) 条")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func planMealPage(
        _ suggestion: MealSuggestion,
        index: Int,
        logs: [FoodLog]
    ) -> some View {
        let loggedKcal = logs.reduce(0.0) { $0 + $1.kcal }
        let colors: [Color] = [Theme.cobalt, Theme.lime, Theme.coral, Theme.cobaltWarm]
        let color = colors[index % colors.count]

        return notebookPage(accent: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(suggestion.name)
                        .font(AppType.title)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("建议 \(suggestion.kcal) kcal")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(suggestion.items.indices, id: \.self) { index in
                        let item = suggestion.items[index]
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(item)
                                .font(AppType.callout)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }

                InkDivider()

                HStack(spacing: 8) {
                    Text(loggedKcal > 0 ? "已记录 \(Int(loggedKcal)) kcal" : "还没记录")
                        .font(AppType.micro)
                        .foregroundStyle(loggedKcal > 0 ? Theme.cobalt : Theme.tertiaryText)
                    Spacer()
                    Button {
                        selectedMeal = mealType(for: suggestion)
                        showAddFood = true
                    } label: {
                        Label(loggedKcal > 0 ? "补记" : "记录这餐", systemImage: "plus")
                            .font(AppType.micro.weight(.bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.paper, in: Capsule(style: .continuous))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(color, lineWidth: 1)
                            }
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.96))
                }
            }
        }
    }

    private func logMealPage(_ meal: MealType, logs: [FoodLog]) -> some View {
        let suggestion = meals.first { mealType(for: $0) == meal }
        let target = suggestion?.kcal ?? 0
        let logged = logs.reduce(0.0) { $0 + $1.kcal }
        let color: Color = {
            switch meal {
            case .breakfast: return Theme.cobalt
            case .lunch: return Theme.lime
            case .dinner: return Theme.coral
            case .snack: return Theme.cobaltWarm
            }
        }()

        return notebookPage(accent: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(meal.label)
                        .font(AppType.title)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(target > 0 ? "\(Int(logged)) / \(target) kcal" : "\(Int(logged)) kcal")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                        .monospacedDigit()
                    Button {
                        selectedMeal = meal
                        showAddFood = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.92))
                }

                if logs.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "square.dashed")
                            .foregroundStyle(Theme.tertiaryText)
                        Text("还没有记录，点右上角加一条。")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .padding(.vertical, 6)
                } else {
                    ForEach(logs) { log in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.foodName)
                                    .font(AppType.callout.weight(.medium))
                                    .foregroundStyle(Theme.ink)
                                Text("\(log.grams.formatted()) g · P\(Int(log.protein)) C\(Int(log.carbs)) F\(Int(log.fat))")
                                    .font(AppType.micro)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            Text("\(Int(log.kcal)) kcal")
                                .font(AppType.micro.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                            Button(role: .destructive) {
                                pendingFoodDelete = log
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.danger.opacity(0.72))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("删除 \(log.foodName)")
                        }
                        .padding(.vertical, 4)
                    }
                }

                if logged > 0 {
                    ProgressView(value: min(1, logged / Double(max(1, target))))
                        .tint(color)
                }
            }
        }
    }

    private var addFoodButton: some View {
        Button {
            selectedMeal = suggestedMeal
            showAddFood = true
        } label: {
            Label("添加食物", systemImage: "plus")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func notebookPage<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 4)
                    .padding(.vertical, 12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }

    private func mealType(for suggestion: MealSuggestion) -> MealType {
        if suggestion.name == MealType.breakfast.label { return .breakfast }
        if suggestion.name == MealType.lunch.label { return .lunch }
        if suggestion.name == MealType.dinner.label { return .dinner }
        return .snack
    }

    private var photoFoodCard: some View {
        Button {
            showFoodPhoto = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                    .foregroundStyle(Theme.cobalt)

                VStack(alignment: .leading, spacing: 3) {
                    Text("拍照识别饮食")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("拍一餐，估算热量与三大营养素")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.paper,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var weekPlanCard: some View {
        Button {
            showWeekPlan = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(Theme.cobalt)

                VStack(alignment: .leading, spacing: 3) {
                    Text("本周饮食计划")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("碳循环 / 低碳 / 高蛋白 · 一周安排")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.paper,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func header(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let consumed = snapshot.totals
        let remainingKcal = max(0, targets.kcal - Int(consumed.kcal))
        let remainingProtein = max(0, targets.protein - Int(consumed.protein))
        let goalLabel = isToday ? "今日" : "当天"

        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isToday ? "TODAY / 今日" : "DAY / 当天")
                    .font(AppType.overline)
                    .tracking(1.4)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Text(date.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(targets.kcal)")
                            .font(AppType.display)
                            .foregroundStyle(Theme.ink)
                        Text("kcal")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Text(remainingKcal > 0
                         ? "还可摄入 \(remainingKcal) kcal"
                         : "已达到\(goalLabel)热量目标")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(remainingKcal > 0 ? Theme.cobalt : Theme.coral)
                }
                Spacer()
                ProgressRing(progress: ratio, lineWidth: 8, color: Theme.lime)
                    .frame(width: 66, height: 66)
                    .overlay {
                        VStack(spacing: 0) {
                            Text("\(Int(ratio * 100))%")
                                .font(AppType.caption.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("已摄入")
                                .font(AppType.micro)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
            }

            HStack(spacing: 6) {
                Text("蛋白还差 \(remainingProtein)g")
                Text("·")
                Text("按 \(store.profile.goalType.label) 目标估算")
            }
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.lime)
    }

    private func macroCard(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let totals = snapshot.totals

        return VStack(alignment: .leading, spacing: 12) {
            Text("宏量营养素")
                .font(AppType.headline)

            HStack(spacing: 10) {
                macro("蛋白质", "\(Int(totals.protein)) / \(targets.protein)g", color: Theme.cobalt)
                macro("碳水", "\(Int(totals.carbs)) / \(targets.carbs)g", color: Theme.warning)
                macro("脂肪", "\(Int(totals.fat)) / \(targets.fat)g", color: Theme.coral)
                macro("膳食纤维", "\(Int(totals.fiber)) / \(targets.fiber)g", color: Theme.blue)
            }

            Text("BMR \(targets.bmr) kcal · 维持热量约 \(targets.tdee) kcal")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func todayLogCard(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let totals = snapshot.totals
        let ratio = min(1.0, totals.kcal / Double(max(1, targets.kcal)))

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isToday ? "今日记录" : "当天记录")
                    .font(AppType.headline)
                Spacer()
                Text("\(Int(totals.kcal)) / \(targets.kcal) kcal")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            ProgressView(value: ratio)
                .tint(Theme.cobalt)

            if snapshot.logs.isEmpty {
                Text("还没有记录。记下吃了什么，才能知道离目标还差多少。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button("记录第一餐") {
                    selectedMeal = suggestedMeal
                    showAddFood = true
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                ForEach(MealType.allCases) { meal in
                    mealLogSection(meal, logs: snapshot.byMeal[meal] ?? [])
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
    private func mealLogSection(_ meal: MealType, logs: [FoodLog]) -> some View {
        if !logs.isEmpty {
            HStack {
                Text(meal.label)
                    .font(AppType.callout.weight(.semibold))
                Spacer()
                Text("\(Int(logs.reduce(0.0) { $0 + $1.kcal })) kcal")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Button {
                    selectedMeal = meal
                    showAddFood = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)

            ForEach(logs) { log in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.foodName)
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                        Text("\(log.grams.formatted()) g")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    Spacer()
                    Text("\(Int(log.kcal)) kcal")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Button(role: .destructive) {
                        pendingFoodDelete = log
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 9.5, weight: .medium))
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(aiMeals == nil ? "建议餐单" : "AI 饮食计划")
                        .font(AppType.headline)
                    Text(aiMeals == nil
                         ? "按目标热量估算；点右侧让 AI 按你的档案生成。"
                         : "根据你的档案、体型和目标生成，可随时重新生成。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    Task { await generateAIPlan() }
                } label: {
                    if isGeneratingPlan {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("生成中…")
                        }
                    } else {
                        Label(aiMeals == nil ? "AI 生成" : "重新生成", systemImage: "sparkles")
                    }
                }
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.cobalt)
                .disabled(isGeneratingPlan || !store.canUseRemoteAI)
            }

            if !aiPlanNote.isEmpty {
                Text(aiPlanNote)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func macro(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            Text(value)
                .font(AppType.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func mealCard(_ meal: MealSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(meal.name)
                    .font(AppType.headline)
                Spacer()
                Text("约 \(meal.kcal) kcal")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            ForEach(meal.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Theme.cobalt.opacity(0.8))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(AppType.callout)
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
                    .foregroundStyle(Theme.cobalt)
                Text("附近外卖")
                    .font(AppType.headline)
            }

            Text("美团联盟只提供活动/搜索跳转，不提供菜品营养数据。点开后请按商家页面为准。")
                .font(AppType.caption)
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
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var disclaimer: some View {
        Text("饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等特殊情况请咨询医生或营养师。")
            .font(.system(size: 9.5, weight: .medium))
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

    let date: Date

    @State private var meal: MealType
    @State private var query = ""
    @State private var selected: FoodItem?
    @State private var grams: Double = 100
    @State private var showCustomFood = false
    @State private var customInitialName = ""
    @State private var addedFoods: [String] = []

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
                            Text("可以继续搜索添加，全部记好后点右上角「完成」。")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Theme.tertiaryText)
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

                    Text("记录是为了了解，不是为了给食物打分。奶茶、火锅、螺蛳粉都可以记。")
                        .font(.system(size: 9.5, weight: .medium))
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
                                    .padding(12)
                                    .background(
                                        Theme.ink.opacity(0.035),
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
                selectedMetric("\(Int(food.protein * factor))g", "蛋白质", Theme.cobalt)
                selectedMetric("\(Int(food.carbs * factor))g", "碳水", Theme.warning)
                selectedMetric("\(Int(food.fat * factor))g", "脂肪", Theme.coral)
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
                        Text("如果吃的是一整碗/一整份，填整份重量。螺蛳粉通常约 500–700g。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
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
                        Text("这些数值会按“这一份”换算成每 100g 保存，下次搜索这个食物时可以直接复用。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
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

                    Text("没有“好食物/坏食物”。记录只是帮你了解今天吃了什么。")
                        .font(.system(size: 9.5, weight: .medium))
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
