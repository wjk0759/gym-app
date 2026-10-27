import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// 每个训练日一条每周重复通知，最多 7 条，避免触发 iOS 的 64 条限制。
    @discardableResult
    func schedule(plan: TrainingPlan?, hour: Int, minute: Int) async -> Int {
        center.removeAllPendingNotificationRequests()
        guard let plan else { return 0 }

        var scheduled = 0
        for day in plan.firstWeek {
            let content = UNMutableNotificationContent()
            content.title = "该训练了"
            content.body = "今天练\(day.title)，约 \(day.estimatedMinutes) 分钟"
            content.sound = .default
            content.userInfo = ["weekday": day.weekday, "day_id": day.id.uuidString]

            var components = DateComponents()
            components.weekday = day.weekday == 7 ? 1 : day.weekday + 1
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: "workout-\(day.weekday)",
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                // 单条失败不影响其它训练日
            }
        }
        return scheduled
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// 训练上传成功后立即提醒查看服务端生成的复盘；本地通知不依赖 APNs。
    func notifyReviewReady() {
        let content = UNMutableNotificationContent()
        content.title = "AI 复盘已更新"
        content.body = "本周训练已完成，查看完成率、强度与下周建议。"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "weekly-review-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        Task { [weak self] in
            guard let self else { return }
            try? await self.center.add(request)
        }
    }
}
