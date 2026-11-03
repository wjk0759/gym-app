import SwiftUI

extension CoachOnboardingView {
    var bodyFatStep: some View {
        let selectedType = bodyType ?? recommendedBodyType
        return VStack(alignment: .leading, spacing: 16) {
            EditorialHeader(
                eyebrow: "身体基线",
                title: "下面哪个体脂图和您最接近"
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 12
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
        }
    }

    var bodyTypeStep: some View {
        let selectedType = bodyType ?? recommendedBodyType
        return VStack(alignment: .leading, spacing: 14) {
            EditorialHeader(
                eyebrow: "身体基线",
                title: "请选择您的体型"
            )

            VStack(spacing: 6) {
                BodyFigure(type: selectedType, sex: draft.sex)
                    .frame(height: 300)
                    .shadow(color: Theme.shadow, radius: 18, y: 10)

                Text("\(selectedType.label)身材：\(selectedType.detail)")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BodyType.options(for: draft.sex)) { type in
                        BodyTypeThumbnail(
                            type: type,
                            sex: draft.sex,
                            selected: bodyType == type
                        ) {
                            bodyType = type
                            if focusAreas.isEmpty {
                                focusAreas = recommendedFocus
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .onAppear {
            guard bodyType == nil else { return }
            bodyType = recommendedBodyType
            if focusAreas.isEmpty {
                focusAreas = recommendedFocus
            }
        }
    }
}
