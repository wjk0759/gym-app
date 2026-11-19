import Foundation

/// 计划生成冷却：30 秒客户端提示，实际限流/日限仍由服务端决定。
enum PlanGenerationCooldown {
    static let seconds: TimeInterval = 30

    static func remainingSeconds(
        lastGeneratedAt: Date?,
        now: Date = Date()
    ) -> Int {
        guard let lastGeneratedAt else { return 0 }
        let remaining = seconds - now.timeIntervalSince(lastGeneratedAt)
        return max(0, Int(remaining.rounded(.up)))
    }

    static func message(remaining: Int) -> String {
        "还需 \(remaining) 秒才能再次生成计划"
    }
}
