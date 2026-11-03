import SwiftUI

extension CoachChatView {
    /// Inline paywall shown after the free weekly coach quota is used up.
    /// Keeping it outside the message list makes it visible without scrolling
    /// and avoids inserting a fake assistant bubble.
    var coachQuotaCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 34, height: 34)
                    .background(
                        Theme.primary,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("免费 AI 教练额度已用完")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("升级 Pro，继续不限条数对话。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 8)

                Button("升级 Pro") {
                    store.requestPro(.coachAI)
                }
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.cobalt, in: Capsule(style: .continuous))
                .buttonStyle(.plain)
            }

            Text("如有胸痛、眩晕、呼吸困难等紧急情况，请立即停止训练并就医。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
