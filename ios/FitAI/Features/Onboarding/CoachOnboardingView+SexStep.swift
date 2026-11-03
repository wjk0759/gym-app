import SwiftUI

extension CoachOnboardingView {
    var sexStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "身体基线",
                title: "你的性别是？",
                subtitle: "用于估算基础代谢和训练负荷。"
            )

            HStack(spacing: 10) {
                sexChoiceCard(.male)
                sexChoiceCard(.female)
            }

            sexHero
                .padding(.top, 2)
        }
    }

    func sexChoiceCard(_ sex: Sex) -> some View {
        let selected = draft.sex == sex
        return Button {
            Haptics.select()
            withAnimation(Motion.smooth) {
                draft.sex = sex
            }
        } label: {
            HStack(spacing: 8) {
                BodyFigurePortrait(sex: sex)
                    .frame(width: 52, height: 52)
                    .background(
                        Theme.ink.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
                    .shadow(color: Theme.shadow, radius: 4, y: 2)

                HStack(spacing: 4) {
                    Image(systemName: sex == .male ? "mars" : "venus")
                        .font(.system(size: 12, weight: .bold))
                    Text(sex.label)
                        .font(AppType.callout.weight(.semibold))
                }
                .foregroundStyle(Theme.ink)

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 18, height: 18)
                        .background(Theme.primary, in: Circle())
                } else {
                    Color.clear
                        .frame(width: 18, height: 18)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(
                selected ? Theme.primary.opacity(0.16) : Theme.paper,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? Theme.ink.opacity(0.82) : Theme.stroke,
                        lineWidth: selected ? 1.6 : 1
                    )
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel(sex.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var sexHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Theme.paper)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Theme.ink.opacity(0.08), .clear],
                        center: .top,
                        startRadius: 10,
                        endRadius: 240
                    )
                )

            BodyFigure(
                type: BodyFigureAsset.representativeType(for: draft.sex),
                sex: draft.sex
            )
            .frame(height: 300)
            .padding(.top, 10)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Theme.shadow, radius: 18, y: 10)
            .id(draft.sex)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
