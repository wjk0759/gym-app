import SwiftUI

extension HomeV2View {
    var nutritionPulse: some View {
        let targets = store.currentNutritionTargets
        let consumed = store.todayNutrition
        let remaining = max(0, targets.kcal - Int(consumed.kcal))
        let proteinLeft = max(0, targets.protein - Int(consumed.protein))

        return NavigationLink(value: TabRoute.nutrition(nil)) {
            HStack(spacing: 14) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日饮食")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("剩余 \(remaining) kcal · 蛋白 \(proteinLeft)g")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
