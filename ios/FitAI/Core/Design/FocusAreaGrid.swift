import SwiftUI

/// Shared card used by the equipment and training-focus pickers.
struct SelectionOptionCard: View {
    let title: String
    let systemImage: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onPrimary : Theme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(
                        selected ? Theme.primary : Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                Text(title)
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
                    .strokeBorder(
                        selected ? Theme.ink.opacity(0.65) : Theme.stroke,
                        lineWidth: selected ? 1.4 : 1
                    )
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Training-focus selection. An empty set means balanced training; the
/// "均衡练全身" card is the visual representation of that state.
struct FocusAreaGrid: View {
    @Binding var selected: Set<BodyFocusArea>

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(BodyFocusArea.displayOrder) { area in
                SelectionOptionCard(
                    title: area.label,
                    systemImage: area.symbol,
                    selected: selected.contains(area)
                ) {
                    toggle(area)
                }
            }

            SelectionOptionCard(
                title: "均衡练全身",
                systemImage: "figure.stand",
                selected: selected.isEmpty
            ) {
                Haptics.select()
                selected.removeAll()
            }
        }
    }

    private func toggle(_ area: BodyFocusArea) {
        Haptics.select()
        if selected.contains(area) {
            selected.remove(area)
        } else {
            selected.insert(area)
        }
    }
}
