import SwiftUI

extension BodyPhotoAnalysisView {
    func resultCard(_ analysis: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("分析结果")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("参考置信度 \(Int(analysis.confidence * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            Text(analysis.summary)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("建议训练重点")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(analysis.focusAreas) { muscle in
                        TagChip(text: muscle.label, selected: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(analysis.recommendations, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.cobalt)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text(analysis.disclaimer)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.applyBodyAnalysis(analysis)
                dismiss()
            } label: {
                Label(
                    analysis.appliedToPlan ? "已应用到当前计划" : "应用到训练计划",
                    systemImage: "wand.and.stars"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(analysis.appliedToPlan)

            Button {
                store.openCoachAfterBodyAnalysis(analysis)
                dismiss()
            } label: {
                Label("去 AI 教练继续", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }
}
