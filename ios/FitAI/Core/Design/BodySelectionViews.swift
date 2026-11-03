import SwiftUI

struct BodyTypeThumbnail: View {
    let type: BodyType
    var sex: Sex = .male
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 6) {
                BodyFigure(type: type, sex: sex)
                    .frame(height: 104)
                    .padding(.horizontal, 4)
                    .shadow(color: Theme.shadow, radius: 6, y: 3)

                Text(type.label)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(
                        selected ? Theme.ink : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
            }
            .padding(8)
            .frame(width: 104)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Theme.stroke, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.97))
        .accessibilityLabel(type.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct BodyFatCard: View {
    let option: BodyFatOption
    var type: BodyType = .rectangle
    var sex: Sex = .male
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 8) {
                BodyFigure(
                    type: type,
                    sex: sex,
                    fatOptionID: option.id,
                    crop: .torso
                )
                .frame(height: 170)
                .padding(.horizontal, 6)

                Text("体脂率 \(option.label)")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        selected ? Theme.ink : Theme.ink.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }
            .padding(8)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Theme.stroke, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel("体脂率 \(option.label)，\(option.note)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
