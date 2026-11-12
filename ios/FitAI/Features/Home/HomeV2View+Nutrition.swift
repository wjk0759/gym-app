import SwiftUI

extension HomeV2View {
    // MARK: - Nutrition

    var nutritionPulse: some View {
        let cached = store.dailyNutritionTargetsKey == FitnessDate.key(Date())
            ? store.dailyNutritionTargets
            : nil
        let targets = cached ?? DietPlanner.targets(profile: store.profile)
        let consumed = store.todayNutrition
        let remaining = max(0, targets.kcal - Int(consumed.kcal))
        let proteinLeft = max(0, targets.protein - Int(consumed.protein))
        let ratio = min(1, consumed.kcal / Double(max(1, targets.kcal)))

        return NavigationLink(value: TabRoute.nutrition(nil)) {
            HStack(spacing: 12) {
                ProgressRing(progress: ratio, lineWidth: 6, color: Theme.lime)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text("\(Int(ratio * 100))%")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.ink)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("今日饮食")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("还能吃 \(remaining) kcal · 蛋白还差 \(proteinLeft)g")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }
}
