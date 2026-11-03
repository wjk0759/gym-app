import SwiftUI

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

    var toolRow: some View {
        HStack(spacing: 8) {
            toolTile(
                title: "拍照识别",
                detail: "估算热量",
                symbol: "camera.viewfinder",
                accent: Theme.lime
            ) {
                if store.requirePro(.foodPhoto) {
                    showFoodPhoto = true
                }
            }
            toolTile(
                title: "本周计划",
                detail: "换饮食策略",
                symbol: "calendar.badge.clock",
                accent: Theme.ink,
                foreground: Theme.onAccent
            ) {
                showWeekPlan = true
            }
        }
    }

    func toolTile(
        title: String,
        detail: String,
        symbol: String,
        accent: Color,
        foreground: Color = Theme.onPrimary,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(foreground)
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

    func macroStrip(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
        let totals = snapshot.totals
        return VStack(spacing: 8) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 6),
                    GridItem(.flexible(), spacing: 6)
                ],
                spacing: 6
            ) {
                macroPill("蛋白", value: totals.protein, target: targets.protein, color: Theme.primary)
                macroPill("碳水", value: totals.carbs, target: targets.carbs, color: Theme.secondary)
                macroPill("脂肪", value: totals.fat, target: targets.fat, color: Theme.primary)
                macroPill("纤维", value: totals.fiber, target: targets.fiber, color: Theme.secondary)
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

    func macroPill(_ title: String, value: Double, target: Int, color: Color) -> some View {
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

    var planHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日食谱")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
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

    func planMealPage(
        _ suggestion: MealSuggestion,
        index: Int,
        logs: [FoodLog]
    ) -> some View {
        let loggedKcal = logs.reduce(0.0) { $0 + $1.kcal }
        let colors: [Color] = [Theme.primary, Theme.secondary]
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
                            .foregroundStyle(Theme.ink)
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

    func mealType(for suggestion: MealSuggestion) -> MealType {
        if suggestion.name == MealType.breakfast.label { return .breakfast }
        if suggestion.name == MealType.lunch.label { return .lunch }
        if suggestion.name == MealType.dinner.label { return .dinner }
        return .snack
    }

    func header(snapshot: DayLogsSnapshot, targets: NutritionTargets) -> some View {
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

    @ViewBuilder

    var disclaimer: some View {
        Text("饮食建议为估算，不构成医疗或疾病饮食处方。孕期、术后、糖尿病、肾病等特殊情况请咨询医生或营养师。")
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }
}
