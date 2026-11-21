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

    /// 每日习惯提醒：喝水、蛋白质、睡眠、称重。与按训练日生成的一次性提醒
    /// 分开存放，关闭训练提醒时不会误删习惯提醒。
    @discardableResult
    func scheduleHabitReminder(kind: String, hour: Int, minute: Int) async -> Bool {
        let identifier = "habit-\(kind)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        switch kind {
        case "hydration":
            content.title = "喝口水"
            content.body = "别等渴了才想起来，先补一杯。"
        case "protein":
            content.title = "补蛋白质"
            content.body = "下一餐优先安排蛋白质，别拖到晚上。"
        case "sleep":
            content.title = "准备收尾"
            content.body = "早点睡，恢复也是训练的一部分。"
        case "weight":
            content.title = "上秤记一下"
            content.body = "看趋势，不看单日波动。"
        default:
            return false
        }
        content.sound = .default
        content.userInfo = ["kind": "habit", "habit": kind]

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancelHabitReminder(kind: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: ["habit-\(kind)"]
        )
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Turning off weekly training reminders must not cancel an active rest
    /// notification. Keep this scoped to the workout identifiers.
    func cancelWorkoutReminders() {
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("workout-") }
            self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func cancelRestNotifications() {
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("rest-") }
            self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    func scheduleRestEnd(
        at date: Date,
        identifier: String,
        exerciseName: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = exerciseName.isEmpty
            ? "可以开始下一组了"
            : "下一组：\(exerciseName)"
        content.sound = .default
        content.threadIdentifier = "rest-timer"
        content.userInfo = ["kind": "rest"]

        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: interval,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request) { _ in }
    }

    func cancelRestEnd(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
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
