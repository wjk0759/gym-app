import SwiftUI

/// 饮食方案库：先选策略，再生成一周餐单。复用现有 diet 模块，不新开数据链路。
struct DietLibraryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: DietChoice?

    private struct DietChoice: Identifiable {
        let id: String
        let label: String
    }

    private struct StrategyInfo: Identifiable {
        let id: String
        let label: String
        let tagline: String
        let description: String
        let caution: String
        let symbol: String
        let color: Color
        let tags: [String]
    }

    private let strategies: [StrategyInfo] = [
        StrategyInfo(
            id: "balanced",
            label: "均衡饮食",
            tagline: "最稳，也最容易坚持",
            description: "蛋白质、主食和蔬菜都保留，适合大多数人作为长期底盘。",
            caution: "不需要刻意戒主食；先保证每餐有蛋白质和蔬菜。",
            symbol: "circle.grid.cross",
            color: Theme.accent,
            tags: ["日常", "长期"]
        ),
        StrategyInfo(
            id: "high_protein",
            label: "高蛋白",
            tagline: "力量训练优先",
            description: "提高蛋白质占比，适合增肌、减脂期保肌肉和训练后恢复。",
            caution: "肾病或肾功能异常人群需先咨询医生。",
            symbol: "bolt.heart.fill",
            color: Theme.blue,
            tags: ["增肌", "保肌肉"]
        ),
        StrategyInfo(
            id: "carb_cycle",
            label: "碳循环",
            tagline: "训练日高碳，休息日低碳",
            description: "把主食更多放在训练日，休息日适度降低碳水，蛋白质每天固定。",
            caution: "高强度训练、孕期、糖尿病或肾病人群不建议自行使用。",
            symbol: "arrow.triangle.2.circlepath",
            color: Theme.warning,
            tags: ["训练日", "进阶"]
        ),
        StrategyInfo(
            id: "low_carb",
            label: "低碳",
            tagline: "控制主食，不挨饿",
            description: "减少精制主食，用蛋白质、蔬菜和适量健康脂肪提高饱腹感。",
            caution: "不适合高强度训练日、孕期、糖尿病或肾病人群自行使用。",
            symbol: "leaf.fill",
            color: Color(red: 0.44, green: 0.78, blue: 0.35),
            tags: ["控糖", "减脂"]
        )
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    targetCard

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "选一个策略", subtitle: "不是少吃，是吃对。")
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)
                            ],
                            spacing: 10
                        ) {
                            ForEach(strategies) { strategy in
                                strategyCard(strategy)
                            }
                        }
                    }

                    foodGuide
                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("饮食方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selected) { choice in
                WeekDietPlanView(
                    initialStrategy: choice.id,
                    forceStrategy: true
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                Text("吃法选明白，\n三餐不瞎猜。")
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("先选策略，再按你的目标和体重生成一周餐单。所有方案都保留替换空间。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HeroGlyph(
                symbol: "fork.knife",
                size: 118,
                tint: Theme.onMedia
            )
            .offset(x: 12, y: 4)
        }
    }

    private var targetCard: some View {
        let targets = DietPlanner.targets(profile: store.profile)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("我的目标 · \(store.profile.goalType.label)", systemImage: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text("每日目标")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            HStack(spacing: 8) {
                targetMetric("\(targets.kcal)", "kcal")
                targetMetric("\(targets.protein)g", "蛋白")
                targetMetric("\(targets.carbs)g", "碳水")
                targetMetric("\(targets.fat)g", "脂肪")
            }

            Text("按当前体重、目标和每周 \(store.profile.weeklyDays) 练估算，结果是区间，不需要精确到个位数。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func targetMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func strategyCard(_ strategy: StrategyInfo) -> some View {
        Button {
            Haptics.select()
            selected = DietChoice(id: strategy.id, label: strategy.label)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: strategy.symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(strategy.color)
                        .frame(width: 34, height: 34)
                        .background(strategy.color.opacity(0.12), in: Circle())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Text(strategy.label)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Text(strategy.tagline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(strategy.color)
                    .lineLimit(1)

                Text(strategy.description)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    ForEach(strategy.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.surfaceStrong, in: Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .padding(14)
            .background(
                Theme.cardSurface,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var foodGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "每餐这样搭", subtitle: "按手掌和拳头估份量，比称重更容易坚持。")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                guideItem("蛋白质", "1 掌心 · 约 20–30g", "fish.fill", Theme.blue)
                guideItem("蔬菜", "2 拳 · 约 200–300g", "leaf.fill", Theme.accent)
                guideItem("主食", "1 拳 · 约 50–100g 熟重", "takeoutbag.and.cup.and.straw.fill", Theme.warning)
                guideItem("油脂", "1 拇指 · 约 10g", "drop.fill", Theme.tertiaryText)
            }
        }
        .card()
    }

    private func guideItem(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private var disclaimer: some View {
        Text("饮食方案只做日常营养估算，不提供疾病饮食处方。孕期、糖尿病、肾病、进食障碍或术后人群，请先咨询医生或注册营养师。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}
