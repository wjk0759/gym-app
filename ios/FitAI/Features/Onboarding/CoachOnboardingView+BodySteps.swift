import SwiftUI

extension CoachOnboardingView {
    var bodyFatStep: some View {
        let selectedType = bodyType ?? recommendedBodyType
        return VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "身体基线",
                title: "哪个体脂范围更像你？",
                subtitle: "按「\(selectedType.label)」的腰腹、手臂线条对比，不用知道精确数字。"
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                spacing: 10
            ) {
                ForEach(BodyFatOption.options(for: draft.sex)) { option in
                    BodyFatCard(
                        option: option,
                        type: selectedType,
                        sex: draft.sex,
                        selected: bodyFatID == option.id
                    ) {
                        bodyFatID = option.id
                        draft.bodyFatPCT = option.midpoint
                    }
                }
            }

            Button {
                let options = BodyFatOption.options(for: draft.sex)
                let fallback = options.min {
                    abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
                } ?? options[2]
                bodyFatID = fallback.id
                draft.bodyFatPCT = fallback.midpoint
                advance()
            } label: {
                Label("不确定，按常见范围估算", systemImage: "sparkles")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
    }

    var bodyTypeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "身体基线",
                title: "你更接近哪种体型？",
                subtitle: "先选最像的体型，下一步再按它选体脂范围。"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(BodyType.options(for: draft.sex)) { type in
                    BodyTypeCard(
                        type: type,
                        sex: draft.sex,
                        selected: bodyType == type,
                        recommended: type == recommendedBodyType
                    ) {
                        bodyType = type
                        if focusAreas.isEmpty {
                            focusAreas = recommendedFocus
                        }
                    }
                }
            }
        }
    }

}
