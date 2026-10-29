import SwiftUI

/// One tappable dish inside a weekly meal.
struct DietDishRow: View {
    let dish: RemoteDietDish
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dish.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(dish.items.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text("看做法")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)

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
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.primaryText)
                            }
                        }
                        .card()

                        sectionTitle("做法")
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { pair in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(pair.offset + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.onAccent)
                                        .frame(width: 22, height: 22)
                                        .background(Theme.accent, in: Circle())
                                    Text(pair.element)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.primaryText)
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
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .card(padding: 14)
                        }
                    } else {
                        Text("这道菜暂时没有详细菜谱，可以先按食材清单准备；重新生成周计划后会补充做法。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .card()
                    }
                }
                .padding(20)
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
            Text(selection.dish.name)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
            Text("\(selection.dayTitle) · \(selection.mealName)")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Text(selection.dish.items.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
    }
}
