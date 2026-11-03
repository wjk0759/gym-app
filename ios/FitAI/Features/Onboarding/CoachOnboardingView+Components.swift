import SwiftUI

extension CoachOnboardingView {
    // MARK: - Components

    func stepTitle(eyebrow: String, title: String, subtitle: String) -> some View {
        EditorialHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
    }

    func valueControl(
        title: String,
        value: String,
        unit: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppType.numberSmall)
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(unit)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 38, height: 38)
                    .background(Theme.primary, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    func choiceCard(
        title: String,
        detail: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.cobalt)
                    .frame(width: 38, height: 38)
                    .background(selected ? Theme.cobalt : Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Theme.cobalt : Theme.tertiaryText)
            }
            .padding(14)
            .background(selected ? Theme.cobalt.opacity(0.055) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 1.8 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func goalCard(_ goal: GoalType) -> some View {
        let selected = draft.goalType == goal
        return Button {
            selectGoal(goal)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goalSymbol(goal))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.cobalt)
                    .frame(width: 48, height: 48)
                    .background(selected ? Theme.cobalt : Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(goal.label)
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        if goal == recommendedGoal {
                            RecommendationBadge(text: "建议")
                        }
                    }
                    Text(goal.detail)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Theme.cobalt : Theme.tertiaryText)
            }
            .padding(14)
            .background(selected ? Theme.cobalt.opacity(0.055) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 1.8 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func equipmentCard(_ item: Equipment) -> some View {
        let selected = draft.equipment.contains(item)
        return Button {
            Haptics.select()
            if selected {
                if draft.equipment.count > 1 { draft.equipment.remove(item) }
            } else {
                draft.equipment.insert(item)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onPrimary : Theme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(selected ? Theme.primary : Theme.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(item.label)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(10)
            .background(selected ? Theme.lime.opacity(0.18) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.ink.opacity(0.65) : Theme.stroke, lineWidth: selected ? 1.4 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    func gaugeRow(
        title: String,
        value: String,
        progress: Double,
        color: Color,
        left: String,
        right: String
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(value)
                    .font(AppType.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stroke)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * max(0.02, min(1, progress)))
                }
            }
            .frame(height: 5)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
        }
    }

    func actionLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(Theme.lime)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
