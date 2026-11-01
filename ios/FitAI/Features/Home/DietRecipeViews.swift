import SwiftUI

/// One tappable dish inside a weekly meal.
struct DietDishRow: View {
    let dish: RemoteDietDish
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "book.closed.fill")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cobalt)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(dish.items.joined(separator: " · "))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text("看做法")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看\(dish.name)的做法")
    }
}

struct DietRecipeSheet: View {
    let selection: DietRecipeSelection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let recipe = selection.dish.recipe {
                        sectionTitle("食材")
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { pair in
                                Label(pair.element, systemImage: "checkmark.circle.fill")
                                    .font(AppType.callout)
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .card()

                        sectionTitle("做法")
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { pair in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(pair.offset + 1)")
                                        .font(AppType.caption.weight(.bold))
                                        .foregroundStyle(Theme.onAccent)
                                        .frame(width: 22, height: 22)
                                        .background(Theme.cobalt, in: Circle())
                                    Text(pair.element)
                                        .font(AppType.callout)
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .card()

                        if let tip = recipe.tip, !tip.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Theme.warning)
                                Text(tip)
                                    .font(AppType.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .card(padding: 14)
                        }
                    } else {
                        Text("这道菜暂时没有详细菜谱，可以先按食材清单准备；重新生成周计划后会补充做法。")
                            .font(AppType.callout)
                            .foregroundStyle(Theme.secondaryText)
                            .card()
                    }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("RECIPE / 菜谱")
                .font(AppType.overline)
                .tracking(1.4)
                .foregroundStyle(Theme.cobalt)
            Text(selection.dish.name)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
            Text("\(selection.dayTitle) · \(selection.mealName)")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
            Text(selection.dish.items.joined(separator: " · "))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppType.headline)
            .foregroundStyle(Theme.ink)
    }
}
