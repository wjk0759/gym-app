import SwiftUI

/// 饮食模块的「本周计划」子页：复用 meal_plans，展示一周策略与每日餐单。
struct WeekDietPlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var week: RemoteDietWeek?
    @State private var strategy = "carb_cycle"
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let forceStrategy: Bool

    init(initialStrategy: String? = nil, forceStrategy: Bool = false) {
        _strategy = State(initialValue: initialStrategy ?? "carb_cycle")
        self.forceStrategy = forceStrategy
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
                    if isLoading {
                        ProgressView("正在排本周饮食…")
                            .tint(Theme.accent)
                            .padding(.vertical, 24)
                    } else if let week {
                        weekCard(week)
                    } else if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .card(padding: 14)
                    }
                }
                .padding(20)
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
                await load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("把饮食计划排成一周")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("碳循环会把高碳日放在训练日、低碳日放在休息日，蛋白质每天固定。计划写入后可在营养页按天查看。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var foodGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每餐这样搭")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    foodGuideChip("蛋白 1 掌心", icon: "fish.fill", color: Theme.blue)
                    foodGuideChip("蔬菜 2 拳", icon: "leaf.fill", color: Theme.accent)
                    foodGuideChip("主食 1 拳", icon: "takeoutbag.and.cup.and.straw.fill", color: Theme.warning)
                    foodGuideChip("油脂 1 拇指", icon: "drop.fill", color: Theme.tertiaryText)
                }
            }
        }
        .card(padding: 12)
    }

    private func foodGuideChip(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.10), in: Capsule())
    }

    private var strategyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("饮食策略")
                .font(.headline)
                .foregroundStyle(.white)

            Picker("策略", selection: $strategy) {
                ForEach(strategies, id: \.id) { item in
                    Text(item.label).tag(item.id)
                }
            }
            .pickerStyle(.segmented)

            Text(cautionText)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await generate() }
            } label: {
                Text(week == nil ? "生成本周计划" : "按当前策略重新生成")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading)
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

    private func weekCard(_ week: RemoteDietWeek) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(week.strategy?.label ?? "本周计划")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(week.days.count) 天")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
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
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(meal.items.joined(separator: "、"))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text(day.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(day.targets.targetKcal ?? 0) kcal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .tint(Theme.accent)
                if day.id != week.days.last?.id {
                    Divider().opacity(0.15)
                }
            }

            if let caution = week.strategy?.caution, !caution.isEmpty {
                Text(caution)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    @MainActor
    private func load() async {
        guard store.canUseRemoteAI else {
            errorMessage = "周计划需要连接后端；当前为本地模式。"
            return
        }
        if forceStrategy {
            await generate()
            return
        }
        do {
            let saved = try await APIClient.shared.fetchSavedDietWeek(weekStart: nil)
            if !saved.days.isEmpty {
                week = saved
                if let id = saved.strategy?.id { strategy = id }
                return
            }
            await generate()
        } catch {
            await generate()
        }
    }

    @MainActor
    private func generate() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            week = try await APIClient.shared.fetchDietWeek(
                strategy: strategy,
                weekStart: nil
            )
        } catch {
            errorMessage = "生成失败，请稍后重试。"
        }
    }
}
