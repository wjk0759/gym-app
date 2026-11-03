import SwiftUI

extension SettingsView {
    // MARK: - 数据与隐私

    var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("协议与数据")
                .font(AppType.headline)

            infoRow("隐私政策", icon: "hand.raised") {
                legalDocument = .privacy
            }
            infoRow("用户协议", icon: "doc.text") {
                legalDocument = .terms
            }
            infoRow("健康免责声明", icon: "heart.text.square") {
                legalDocument = .health
            }
            infoRow("AI 记忆", icon: "brain.head.profile") {
                showAgentMemory = true
            }

            Button {
                showExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.cobalt)
                        .frame(width: 22)
                    Text("导出我的数据")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .buttonStyle(.plain)

            infoRow("生成式 AI 服务说明", icon: "checkmark.seal") {
                legalDocument = .ai
            }

            if let repDBURL = URL(string: "https://repdb.co/") {
                Link(destination: repDBURL) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(Theme.cobalt)
                            .frame(width: 22)
                        Text("动作图：Exercise data by RepDB (repdb.co)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
            }

            if let bodyFigureURL = URL(string: "https://sketchfab.com/RawPheasant5745") {
                Link(destination: bodyFigureURL) {
                    HStack {
                        Image(systemName: "figure.stand")
                            .foregroundStyle(Theme.cobalt)
                            .frame(width: 22)
                        Text("体型人台：RawPheasant5745 · CC BY 4.0")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
            }

            Text("本产品不提供医疗诊断或治疗建议。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("版本 \(AppConfig.appVersion)")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    func infoRow(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 22)
                Text(title)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }

    func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Theme.cobalt)
                .frame(width: 12, height: 2)
            Text(text)
                .font(AppType.overline)
                .tracking(1.1)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.horizontal, 2)
    }
}
