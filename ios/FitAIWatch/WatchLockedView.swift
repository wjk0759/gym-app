import SwiftUI

/// Free users see this instead of a blank or broken watch app. The real
/// entitlement refresh is connected through WatchConnectivity in the Pro
/// onboarding step.
struct WatchLockedView: View {
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Apple Watch 训练")
                    .font(.headline)
                Text("叫练 Pro 专属")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text("3D 动作动画 · 离线训练 · 语音教练")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("在 iPhone 打开今日训练完成预载。Pro 会员可用。")
                    .font(.caption2)
                Button("刷新权限", action: onRefresh)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
}
