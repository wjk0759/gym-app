import Foundation

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
