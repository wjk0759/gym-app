import SwiftUI
import UIKit

extension SettingsView {
    var restTimerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("休息提醒")
                        .font(AppType.headline)
                    Text("组间休息时的倒计时和结束提醒")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "timer")
                    .foregroundStyle(
                        store.restLiveActivityEnabled
                            ? Theme.cobalt
                            : Theme.tertiaryText
                    )
            }

            Toggle(
                isOn: Binding(
                    get: { store.restLiveActivityEnabled },
                    set: { store.setRestLiveActivityEnabled($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("锁屏与灵动岛倒计时")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                    Text("休息时在锁屏和灵动岛显示剩余时间")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.primary)

            if !RestLiveActivityManager.shared.areActivitiesEnabled {
                HStack(spacing: 12) {
                    Text("iOS 的「实时活动」未开启，倒计时不会显示。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.coral)
                    Spacer()
                    Button("去系统设置") {
                        openSystemSettings()
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                }
            }

            Toggle(
                isOn: Binding(
                    get: { store.restNotificationsEnabled },
                    set: { enabled in
                        if enabled {
                            Task { @MainActor in
                                let granted = await store.enableRestNotifications()
                                restNotificationAuthorized = granted
                                if !granted {
                                    message = "没有获得通知权限。请到「设置 → 通知 → 叫练」中开启。"
                                    showMessage = true
                                }
                            }
                        } else {
                            store.disableRestNotifications()
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("休息结束提醒")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                    Text("倒计时结束时通知并震动")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.primary)

            if !restNotificationAuthorized {
                HStack(spacing: 12) {
                    Text("系统通知未开启，休息结束不会震动。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.coral)
                    Spacer()
                    Button("去系统设置") {
                        openSystemSettings()
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                }
            }

            Text("关闭倒计时不影响休息结束提醒；关闭提醒不影响倒计时。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
        .task {
            restNotificationAuthorized = await NotificationScheduler.shared.isAuthorized()
            if !restNotificationAuthorized, store.restNotificationsEnabled {
                store.restNotificationsEnabled = false
                store.persist()
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }
}
