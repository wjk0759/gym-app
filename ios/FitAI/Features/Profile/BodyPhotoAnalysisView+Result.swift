import SwiftUI

/// 体型分析结果卡：摘要/重点/建议和后续动作。
/// 卡本身只渲染结果；应用计划/去教练由按钮调用 AppStore。
extension BodyPhotoAnalysisView {
    func resultCard(_ analysis: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if analysis.hasPhoto == true {
                BodyAnalysisPhotoView(analysis: analysis)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }

            BodyAnalysisResultSummary(analysis: analysis)

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
