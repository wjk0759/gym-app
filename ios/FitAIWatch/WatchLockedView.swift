import SwiftUI

enum WatchLockReason {
    case signedOut
    case proRequired

    var detail: String {
        switch self {
        case .signedOut:
            return "在 iPhone 重新登录后刷新。"
        case .proRequired:
            return "在 iPhone 开通 Pro 或预载训练。"
        }
    }
}

/// Free users see this instead of a blank or broken watch app. The real
/// entitlement refresh is connected through WatchConnectivity.
struct WatchLockedView: View {
    let reason: WatchLockReason
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    brandRow
                    Text("Apple Watch 训练")
                        .font(.headline)
                        .foregroundStyle(WatchTheme.ink)
                    Text(reason.detail)
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
            }

            Button("刷新权限", action: onRefresh)
                .buttonStyle(WatchPrimaryButtonStyle())
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
        }
        .background(WatchTheme.canvas)
    }

    private var brandRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WatchTheme.onPrimary)
                .frame(width: 24, height: 24)
                .background(WatchTheme.primary, in: Circle())
            Text("叫练")
                .font(.headline)
                .foregroundStyle(WatchTheme.ink)
            Text("PRO")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(WatchTheme.onPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(WatchTheme.primary, in: Capsule())
        }
    }
}
