import SwiftUI

/// 饮食模块的「本周计划」子页：复用 meal_plans，展示一周策略与每日餐单。
struct WeekDietPlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var week: RemoteDietWeek?
    @State private var strategy = "carb_cycle"
    @State private var isLoading = false
    @State private var didLoad = false
    @State private var errorMessage = ""
    @State private var selectedRecipe: DietRecipeSelection?
    @State private var lastGeneratedAt: Date?
    @State private var pendingGenerationKey: String?

    private let requestedStrategy: String?

    init(initialStrategy: String? = nil) {
        _strategy = State(initialValue: initialStrategy ?? "carb_cycle")
        requestedStrategy = initialStrategy
    }

    private let strategies: [(id: String, label: String)] = [
        ("carb_cycle", "碳循环"),
        ("low_carb", "低碳"),
        ("high_protein", "高蛋白"),
        ("balanced", "均衡")
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    header
                    foodGuide
                    strategyCard
                    if let week,
                       let savedStrategy = week.strategy?.id,
                       savedStrategy != strategy {
                        Text("当前显示的是「\(week.strategy?.label ?? savedStrategy)」计划；点下方「按当前策略重新生成」切换为「\(strategyLabel(strategy))」。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.coral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isLoading {
                        ProgressView("AI 教练正在排本周饮食…")
                            .tint(Theme.cobalt)
                            .padding(.vertical, 24)
                    } else {
                        if let week {
                            weekCard(week)
                        }
                        if !errorMessage.isEmpty {
                            errorCard
                        }
                    }
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("本周饮食计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard !didLoad else { return }
                didLoad = true
                await load()
            }
            .sheet(item: $selectedRecipe) { selection in
                DietRecipeSheet(selection: selection)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("MEAL PLAN / 本周饮食")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("把饮食排成一周")
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("AI 教练会按目标、训练日和饮食策略排本周餐单；每道菜都可以点开看家常做法。AI 暂不可用时会自动回退模板。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var foodGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每餐这样搭")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    foodGuideChip("蛋白 1 掌心", icon: "fish.fill", color: Theme.blue)
                    foodGuideChip("蔬菜 2 拳", icon: "leaf.fill", color: Theme.secondary)
                    foodGuideChip("主食 1 拳", icon: "takeoutbag.and.cup.and.straw.fill", color: Theme.warning)
                    foodGuideChip("油脂 1 拇指", icon: "drop.fill", color: Theme.tertiaryText)
                }
            }
        }
        .card(padding: 12)
    }

    private func foodGuideChip(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var mealPlanAvailable: Bool {
        store.access.policy.canGenerateMealPlan
    }

    private var strategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("饮食策略")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            Picker("策略", selection: $strategy) {
                ForEach(strategies, id: \.id) { item in
                    Text(item.label).tag(item.id)
                }
            }
            .pickerStyle(.segmented)

            Text(cautionText)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            if mealPlanAvailable {
                Button {
                    Task { await generate() }
                } label: {
                    Text(
                        week == nil
                            ? (store.hasProAccess ? "生成本周计划" : "免费生成本周计划")
                            : (store.hasProAccess ? "重新生成本周计划" : "Pro 重新生成本周计划")
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoading)
            } else {
                ProLockedOverlay(feature: .mealPlan) {
                    store.requestPro(.mealPlan)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .card()
    }

    private var cautionText: String {
        switch strategy {
        case "carb_cycle":
            return "训练日高碳、休息日低碳；蛋白质每天固定，总热量不会因为高碳日无限放大。"
        case "low_carb":
            return "碳水约 20–30%；高强度训练、孕期、糖尿病或肾病人群不建议自行使用。"
        case "high_protein":
            return "蛋白质约 2.0–2.2g/kg；肾病或肾功能异常人群需先咨询医生。"
        default:
            return "均衡策略，最稳；适合大多数人。"
        }
    }

    private func strategyLabel(_ id: String) -> String {
        strategies.first { $0.id == id }?.label ?? id
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(errorMessage)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("重试") {
                Task {
                    if week == nil {
                        await generate()
                    } else {
                        await load()
                    }
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card(padding: 14)
    }

    private func weekCard(_ week: RemoteDietWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(week.strategy?.label ?? "本周计划")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(week.generatedBy == "ai" ? "AI 生成" : "模板")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(week.generatedBy == "ai" ? Theme.cobalt : Theme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        (week.generatedBy == "ai" ? Theme.cobalt : Theme.tertiaryText).opacity(0.10),
                        in: Capsule()
                    )
                Spacer()
                Text("\(week.days.count) 天")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if let warning = week.warning, !warning.isEmpty {
                Text(warning)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(week.days) { day in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text("蛋白 \(day.targets.proteinG ?? 0)g")
                            Text("碳水 \(day.targets.carbG ?? 0)g")
                            Text("脂肪 \(day.targets.fatG ?? 0)g")
                        }
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)

                        ForEach(day.meals) { meal in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(meal.name) · \(meal.kcal) kcal")
                                    .font(AppType.caption.weight(.semibold))
                                    .foregroundStyle(Theme.ink)

                                if let dishes = meal.dishes, !dishes.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(dishes.enumerated()), id: \.offset) { pair in
                                            let dish = pair.element
                                            DietDishRow(dish: dish) {
                                                selectedRecipe = DietRecipeSelection(
                                                    dayTitle: day.title,
                                                    mealName: meal.name,
                                                    dish: dish
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    Text(meal.items.joined(separator: "、"))
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text(day.title)
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(day.targets.targetKcal ?? 0) kcal")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                    }
                }
                .tint(Theme.cobalt)
                if day.id != week.days.last?.id {
                    InkDivider()
                }
            }

            if let caution = week.strategy?.caution, !caution.isEmpty {
                Text(caution)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    @MainActor
    private func load() async {
        await store.refreshAccess()
        do {
            let saved = try await NutritionService().fetchSavedWeek(weekStart: nil)
            if !saved.days.isEmpty {
                week = saved
                if requestedStrategy == nil, let id = saved.strategy?.id {
                    strategy = id
                }
            }
        } catch {
            errorMessage = "读取本周计划失败，请重试。"
        }
    }

    @MainActor
    private func generate() async {
        guard !isLoading else { return }
        guard mealPlanAvailable else {
            store.requestPro(.mealPlan)
            return
        }
        if let last = lastGeneratedAt, Date().timeIntervalSince(last) < 60 {
            errorMessage = "本周计划刚刚生成，请稍后再试。"
            return
        }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        let idempotencyKey = pendingGenerationKey ?? UUID().uuidString
        pendingGenerationKey = idempotencyKey
        do {
            week = try await NutritionService().fetchWeek(
                strategy: strategy,
                weekStart: nil,
                idempotencyKey: idempotencyKey
            )
            pendingGenerationKey = nil
            lastGeneratedAt = Date()
            await store.refreshAccess()
        } catch let error as APIError where error.statusCode == 429 {
            if error.code == "GENERATION_IN_PROGRESS" {
                errorMessage = "本周计划正在生成，请稍后查看。"
            } else if let retry = error.retryAfter, retry > 0 {
                errorMessage = "本周计划刚刚生成，请 \(retry) 秒后再试。"
            } else {
                errorMessage = "生成太频繁，请稍后再试。"
            }
        } catch let error as APIError
            where error.isProRequired {
            await store.refreshAccess()
            store.requestPro(.mealPlan)
        } catch {
            errorMessage = "生成失败，请稍后重试。"
        }
    }
}
