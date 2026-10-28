import Foundation

// MARK: - 训练分化

enum SplitType: String, Codable, CaseIterable, Identifiable {
    case one = "1分化"
    case three = "3分化"
    case five = "5分化"

    var id: String { rawValue }

    var title: String { rawValue }

    var detail: String {
        switch self {
        case .one: return "每次练全身，适合 2–3 练"
        case .three: return "推 / 拉 / 腿循环，适合 3–5 练"
        case .five: return "胸 / 背 / 腿 / 肩 / 手臂，适合 4–7 练"
        }
    }
}

// MARK: - 经期

enum PeriodTrainingMode: String, Codable, CaseIterable, Identifiable {
    case light
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "轻重量训练"
        case .rest: return "直接休息"
        }
    }

    var detail: String {
        switch self {
        case .light: return "自动少 1 组，负重约为 80%"
        case .rest: return "经期不安排力量训练"
        }
    }
}

struct PeriodDay: Equatable {
    let day: Int
    let dateKey: String
    let mode: PeriodTrainingMode
}

// MARK: - 身体数据

struct BodyMetric: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var weightKG: Double
    var bodyFatPCT: Double
    var waistCM: Double
    var armCM: Double? = nil
    var thighCM: Double? = nil
    var syncedAt: Date? = nil

    var dateKey: String { FitnessDate.key(date) }
}

enum BodyCheckInFrequency: String, Codable, CaseIterable, Identifiable {
    case off
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        }
    }
}

// MARK: - 日期键

enum FitnessDate {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.firstWeekday = 2
        return calendar
    }()

    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func key(_ date: Date) -> String {
        keyFormatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        keyFormatter.date(from: key)
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func monday(of date: Date) -> Date {
        let start = startOfDay(date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: start) ?? start
    }

    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func endOfDay(_ date: Date) -> Date {
        calendar.date(
            bySettingHour: 23,
            minute: 59,
            second: 59,
            of: startOfDay(date)
        ) ?? date
    }

    static func weekdayNumber(_ date: Date) -> Int {
        let value = calendar.component(.weekday, from: date)
        return value == 1 ? 7 : value - 1
    }

    static func short(_ date: Date) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 1)/\(components.day ?? 1)"
    }
}

// MARK: - 目标进度

struct GoalProgress {
    let startWeight: Double
    let currentWeight: Double
    let targetWeight: Double
    let progress: Int
    let distance: Double?
    let targetDate: Date
    let daysLeft: Int?
    let hasTodayMetric: Bool
    let currentWaist: Double
    let currentBodyFat: Double
    let targetWaist: Double?
    let targetBodyFat: Double?

    var distanceText: String {
        guard targetWeight > 0, let distance else { return "设置目标体重" }
        return distance < 0.05 ? "目标体重已达成" : "还差 \(Self.format(distance)) kg"
    }

    var targetDateText: String {
        targetDate.formatted(.dateTime.year().month().day())
    }

    var dateStatus: String {
        guard let daysLeft else { return "设置目标日期" }
        if daysLeft > 0 { return "还有 \(daysLeft) 天" }
        if daysLeft == 0 { return "今天到期" }
        return "已到期"
    }

    var targetSummary: String {
        var parts: [String] = []
        if let targetWaist, targetWaist > 0 {
            parts.append("腰围 \(Self.format(currentWaist)) → \(Self.format(targetWaist)) cm")
        }
        if let targetBodyFat, targetBodyFat > 0 {
            parts.append("体脂 \(Self.format(currentBodyFat)) → \(Self.format(targetBodyFat))%")
        }
        return parts.joined(separator: " · ")
    }

    static func format(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }
}

// MARK: - 复盘

enum ReviewPeriod: String, CaseIterable, Identifiable, Equatable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "今年"
        }
    }

    var previousTitle: String {
        switch self {
        case .week: return "上周同期"
        case .month: return "上月同期"
        case .year: return "去年同期"
        }
    }
}
