import SwiftUI

/// 饮食页的纯展示层。
///
/// 这里不直接发请求或写库，只负责：
/// - 定制食谱 / 我的记录两种模式；
/// - 工具入口（拍照、本周计划、记一笔）；
/// - 宏量、餐单、记录行和空状态。
extension NutritionView {
    // MARK: - Notebook layout

    var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(NutritionMode.allCases) { item in
                let selected = mode == item
                Button {
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        mode = item
                    }
                } label: {
                    Text(item.title)
                        .font(AppType.callout)
                        .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? Theme.ink : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    /// 三个高频入口。三张卡必须等宽：
    /// 拍照识别走 FoodVision， 本周计划走 WeekDietPlanView， 记一笔走 AddFoodView。
    /// 这里只切换 sheet，不产生任何写入。
    var toolRow: some View {
        HStack(alignment: .top, spacing: 8) {
            toolTile(
                title: "拍照识别",
                symbol: "camera.viewfinder"
            ) {
                if store.requirePro(.foodPhoto) {
                    showFoodPhoto = true
                }
            }
            toolTile(
                title: "本周计划",
                symbol: "calendar"
            ) {
                showWeekPlan = true
            }
            toolTile(
                title: "记一笔",
                symbol: "square.and.pencil"
            ) {
                selectedMeal = suggestedMeal
                showAddFood = true
            }
        }
    }

    func toolTile(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Text(title)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    /// 宏量数据只展示本日已摄入/目标。
    func macroStrip(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let totals = snapshot.totals
        return HStack(spacing: 0) {
            macroValue("蛋白", value: totals.protein)
            macroValue("碳水", value: totals.carbs)
            macroValue("脂肪", value: totals.fat)
            macroValue("纤维", value: totals.fiber)
        }
    }

    private func macroValue(_ title: String, value: Double) -> some View {
        VStack(spacing: 3) {
            Text("\(Int(value))")
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    func planHeader(snapshot: DayLogsSnapshot) -> some View {
        let activeMeals = meals.filter { !$0.skipped }
        let plannedKeys = Set(activeMeals.map(\.meal))
        let loggedKeys = Set(
            snapshot.logs.filter { $0.planDate != nil }.compactMap(\.planMeal)
        )
        let completed = plannedKeys.intersection(loggedKeys).count
        let skippedCount = meals.count - activeMeals.count
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日食谱")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                if !plannedKeys.isEmpty {
                    Text("已记录 \(completed)/\(plannedKeys.count) 餐")
                        .font(AppType.micro)
                        .foregroundStyle(
                            completed >= plannedKeys.count
                                ? Theme.cobalt
                                : Theme.tertiaryText
                        )
                }
                if skippedCount > 0 {
                    Text("已跳过 \(skippedCount) 餐")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
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
            .disabled(isGeneratingPlan)
        }
    }

    func logHeader(snapshot: DayLogsSnapshot) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("我的记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            Text("\(snapshot.logs.count) 条")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    /// 计划餐卡：展示建议餐单、换餐/恢复/撤销，以及“记录整餐”。
    /// `logs` 只用于判断这餐是否已经记录，不会改变计划本身。
    func planMealPage(
        _ suggestion: MealSuggestion,
        index: Int,
        logs: [FoodLog]
    ) -> some View {
        let loggedKcal = logs.reduce(0.0) { $0 + $1.kcal }
        let plannedLog = logs.first {
            $0.planDate != nil && $0.planMeal == suggestion.meal
        }
        let statusText: String
        if suggestion.skipped {
            statusText = "已跳过这餐"
        } else if let plannedLog {
            statusText = "已记录整餐 \(Int(plannedLog.kcal)) kcal"
        } else if loggedKcal > 0 {
            statusText = "已记录 \(Int(loggedKcal)) kcal"
        } else {
            statusText = "还没记录"
        }
        let colors: [Color] = [Theme.primary, Theme.secondary]
        let color = colors[index % colors.count]

        return notebookPage {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(suggestion.name)
                        .font(AppType.title)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(suggestion.kcal) kcal")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                    Button {
                        Task { await swapPlanMeal(suggestion) }
                    } label: {
                        if swappingMeal == suggestion.meal {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.cobalt)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(swappingMeal != nil)
                    .accessibilityLabel("换一餐 \(suggestion.name)")

                    if lastSwappedMeal == suggestion.meal {
                        Button("撤销") {
                            Task { await undoPlanMealSwap(suggestion) }
                        }
                        .font(AppType.micro.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                        .buttonStyle(.plain)
                        .disabled(swappingMeal != nil)
                    }
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
                    Text(statusText)
                        .font(AppType.micro)
                        .foregroundStyle(
                            plannedLog != nil || loggedKcal > 0
                                ? Theme.cobalt
                                : Theme.tertiaryText
                        )
                    Spacer(minLength: 4)

                    if suggestion.skipped {
                        Button {
                            Task { await restorePlanMeal(suggestion) }
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
                                .font(AppType.micro.weight(.bold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(color, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(SubtlePressStyle(scale: 0.96))
                        .disabled(restoringMeal != nil)
                    }

                    if plannedLog == nil && !suggestion.skipped {
                        Button {
                            logPlannedMeal(suggestion)
                        } label: {
                            Label("整餐", systemImage: "checkmark.circle")
                                .font(AppType.micro.weight(.bold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(color, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(SubtlePressStyle(scale: 0.96))
                        .accessibilityLabel("记录整餐 \(suggestion.name)")
                    }

                    Button {
                        selectedMeal = mealType(for: suggestion)
                        showAddFood = true
                    } label: {
                        Label("补记", systemImage: "plus")
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

    /// 记录模式下的单餐卡片：列出本地 FoodLog，编辑/删除都只改本地和服务端记录，
    /// 不会回写计划餐单。
    func logMealPage(_ meal: MealType, logs: [FoodLog]) -> some View {
        let suggestion = meals.first { mealType(for: $0) == meal }
        let target = suggestion?.kcal ?? 0
        let logged = logs.reduce(0.0) { $0 + $1.kcal }
        let color: Color = {
            switch meal {
            case .breakfast: return Theme.cobalt
            case .lunch: return Theme.lime
            case .dinner: return Theme.coral
            case .snack: return Theme.accentWarm
            }
        }()

        return notebookPage {
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
                            .foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.92))
                }

                if !logs.isEmpty {
                    ForEach(logs) { log in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(log.foodName)
                                        .font(AppType.callout.weight(.medium))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(1)
                                    if log.planDate != nil {
                                        Text("计划餐")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(Theme.cobalt)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Theme.cobalt.opacity(0.10), in: Capsule())
                                    }
                                }
                                Text(
                                    log.grams > 0
                                        ? "\(log.grams.formatted()) g · P\(Int(log.protein)) C\(Int(log.carbs)) F\(Int(log.fat))"
                                        : "P\(Int(log.protein)) C\(Int(log.carbs)) F\(Int(log.fat))"
                                )
                                .font(AppType.micro)
                                .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            Text("\(Int(log.kcal)) kcal")
                                .font(AppType.micro.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                            Menu {
                                Button {
                                    editingFoodLog = log
                                } label: {
                                    Label("编辑", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    pendingFoodDelete = log
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                                    .frame(width: 26, height: 26)
                            }
                            .accessibilityLabel("编辑或删除 \(log.foodName)")
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

    var addFoodButton: some View {
        Button {
            selectedMeal = suggestedMeal
            showAddFood = true
        } label: {
            Label("添加食物", systemImage: "plus")
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    func notebookPage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }

    func mealType(for suggestion: MealSuggestion) -> MealType {
        suggestion.meal
    }

    func header(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let consumed = snapshot.totals
        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(consumed.kcal)) / \(targets.kcal) kcal")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Spacer(minLength: 8)
                Text("\(Int(ratio * 100))%")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }
            ProgressView(value: ratio)
                .tint(Theme.primary)
        }
        .card()
    }

    @ViewBuilder

    var disclaimer: some View {
        Text("估算值，不构成医疗建议。")
            .font(AppType.caption)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
