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

    /// 按实际训练日期生成一次性提醒，最多 60 条，支持顺延、跳过和临时改期。
    @discardableResult
    func schedule(plan: TrainingPlan?, hour: Int, minute: Int) async -> Int {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending
                .map(\.identifier)
                .filter { $0.hasPrefix("workout-") }
        )
        guard let plan else { return 0 }

        let calendar = FitnessDate.calendar
        let now = Date()
        let today = calendar.startOfDay(for: now)
        var scheduled = 0

        for day in plan.days
            .filter({ $0.skippedAt == nil })
            .sorted(by: {
                (plan.scheduledDate(for: $0) ?? .distantFuture)
                    < (plan.scheduledDate(for: $1) ?? .distantFuture)
            }) {
            guard scheduled < 60,
                  let date = plan.scheduledDate(for: day) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard dayStart >= today else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components), fireDate > now else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "该训练了"
            content.body = "今天练\(day.title)，约 \(day.estimatedMinutes) 分钟"
            content.sound = .default
            content.userInfo = ["weekday": day.weekday, "day_id": day.id.uuidString]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "workout-\(day.id.uuidString)",
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
    /// 天气提醒也走本地通知。只有用户允许通知且天气服务判定有雨/雪时才会调用。
    @discardableResult
    func notifyWeather(title: String, body: String, identifier: String) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["kind": "weather"]
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

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
