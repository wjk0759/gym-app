import Foundation

struct ReviewSnapshot {
    let sessions: [WorkoutSession]
    let minutes: Int
    let volume: Double
    let sets: Int
    let trainingDays: Int
    let loggedFoodDays: Int
    let totalKcal: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let averageDailyMinutes: Double
    let averageSessionMinutes: Double
    let averageIntake: Double?
    let calorieGap: Double?
    let weight: Double?
    let bodyFat: Double?

    var hasNutrition: Bool { loggedFoodDays > 0 }
}

struct ReviewTrend: Equatable {
    enum Direction: Equatable {
        case up
        case down
        case flat
    }

    enum Tone: Equatable {
        case good
        case bad
        case flat
        case muted
    }

    let direction: Direction
    let tone: Tone
    let text: String
}

struct ReviewKPI: Identifiable {
    let id: String
    let label: String
    let display: String
    let unit: String
    let previousDisplay: String
    let trend: ReviewTrend
    let note: String
}

struct ReviewData {
    let period: ReviewPeriod
    let rangeLabel: String
    let current: ReviewSnapshot
    let previous: ReviewSnapshot
    let kpis: [ReviewKPI]
    let goodCount: Int
    let badCount: Int
    let insufficientCount: Int
    let periodDays: Int
}

enum PlanReviewEngine {
    static func make(store: AppStore, period: ReviewPeriod, now: Date = Date()) -> ReviewData {
        let bounds = bounds(for: period, now: now)
        let targets = DietPlanner.targets(profile: store.profile)
        let current = snapshot(
            store: store,
            start: bounds.currentStart,
            end: bounds.currentEnd,
            days: bounds.periodDays,
            targets: targets,
            fallbackBody: true
        )
        let previous = snapshot(
            store: store,
            start: bounds.previousStart,
            end: bounds.previousEnd,
            days: bounds.previousDays,
            targets: targets,
            fallbackBody: false
        )
        let currentGap = current.calorieGap
        let previousGap = previous.calorieGap

        let trends: [String: ReviewTrend] = [
            "sessions": trend(current: Double(current.sessions.count), previous: Double(previous.sessions.count), mode: .higher, digits: 0, unit: " 次"),
            "duration": trend(current: current.averageDailyMinutes, previous: previous.averageDailyMinutes, mode: .higher, digits: 1, unit: " 分钟"),
            "intake": trend(current: current.averageIntake, previous: previous.averageIntake, mode: .closeness, digits: 0, unit: " kcal", target: Double(targets.kcal)),
            "deficit": trend(current: currentGap, previous: previousGap, mode: .closeness, digits: 0, unit: " kcal", target: 0),
            "weight": trend(current: current.weight, previous: previous.weight, mode: .goalWeight, digits: 1, unit: " kg", target: store.profile.targetWeightKG),
            "bodyFat": trend(current: current.bodyFat, previous: previous.bodyFat, mode: .lower, digits: 1, unit: "%")
        ]

        let kpis: [ReviewKPI] = [
            ReviewKPI(
                id: "sessions",
                label: "训练次数",
                display: "\(current.sessions.count)",
                unit: "次",
                previousDisplay: "\(previous.sessions.count) 次",
                trend: trends["sessions"]!,
                note: "\(current.trainingDays) 个训练日"
            ),
            ReviewKPI(
                id: "duration",
                label: "平均每日时长",
                display: format(current.averageDailyMinutes, digits: 1),
                unit: "分钟",
                previousDisplay: "\(format(previous.averageDailyMinutes, digits: 1)) 分钟",
                trend: trends["duration"]!,
                note: "\(bounds.periodDays) 天周期"
            ),
            ReviewKPI(
                id: "intake",
                label: "日均摄入",
                display: current.averageIntake.map { format($0) } ?? "—",
                unit: "kcal",
                previousDisplay: previous.averageIntake.map { "\(format($0)) kcal" } ?? "—",
                trend: trends["intake"]!,
                note: current.loggedFoodDays > 0 ? "\(current.loggedFoodDays) 天记录" : "暂无记录"
            ),
            ReviewKPI(
                id: "deficit",
                label: "热量缺口",
                display: currentGap.map { format(abs($0)) } ?? "—",
                unit: (currentGap ?? 0) >= 0 ? "kcal 缺口" : "kcal 盈余",
                previousDisplay: previousGap.map { "\(format(abs($0))) kcal" } ?? "—",
                trend: trends["deficit"]!,
                note: "目标 - 日均"
            ),
            ReviewKPI(
                id: "weight",
                label: "体重",
                display: current.weight.map { format($0, digits: 1) } ?? "—",
                unit: "kg",
                previousDisplay: previous.weight.map { "\(format($0, digits: 1)) kg" } ?? "—",
                trend: trends["weight"]!,
                note: store.profile.targetWeightKG > 0 ? "目标 \(format(store.profile.targetWeightKG, digits: 1)) kg" : "未设目标"
            ),
            ReviewKPI(
                id: "bodyFat",
                label: "体脂",
                display: current.bodyFat.map { format($0, digits: 1) } ?? "—",
                unit: "%",
                previousDisplay: previous.bodyFat.map { "\(format($0, digits: 1))%" } ?? "—",
                trend: trends["bodyFat"]!,
                note: "最近测量"
            )
        ]

        let good = trends.values.filter { $0.tone == .good }.count
        let bad = trends.values.filter { $0.tone == .bad }.count
        let insufficient = trends.values.filter { $0.tone == .muted }.count

        return ReviewData(
            period: period,
            rangeLabel: bounds.rangeLabel,
            current: current,
            previous: previous,
            kpis: kpis,
            goodCount: good,
            badCount: bad,
            insufficientCount: insufficient,
            periodDays: bounds.periodDays
        )
    }

    private struct Bounds {
        let currentStart: Date
        let currentEnd: Date
        let previousStart: Date
        let previousEnd: Date
        let periodDays: Int
        let previousDays: Int
        let rangeLabel: String
    }

    private static func bounds(for period: ReviewPeriod, now: Date) -> Bounds {
        let calendar = FitnessDate.calendar
        let currentEnd = FitnessDate.endOfDay(now)
        let currentStart: Date
        let previousStart: Date
        let periodDays: Int
        let previousDays: Int

        switch period {
        case .week:
            currentStart = FitnessDate.monday(of: now)
            periodDays = max(1, (calendar.dateComponents([.day], from: currentStart, to: FitnessDate.startOfDay(now)).day ?? 0) + 1)
            previousStart = FitnessDate.addingDays(-7, to: currentStart)
            previousDays = periodDays
        case .month:
            currentStart = FitnessDate.startOfMonth(now)
            periodDays = calendar.component(.day, from: now)
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
            previousStart = FitnessDate.startOfMonth(previousMonth)
            let previousMonthDays = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 28
            previousDays = min(periodDays, previousMonthDays)
        case .year:
            currentStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            periodDays = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
            previousStart = calendar.date(byAdding: .year, value: -1, to: currentStart) ?? currentStart
            let nextYearStart = calendar.date(byAdding: .year, value: 1, to: previousStart) ?? previousStart
            let previousYearDays = calendar.dateComponents([.day], from: previousStart, to: nextYearStart).day ?? 365
            previousDays = min(periodDays, previousYearDays)
        }

        let previousEnd = FitnessDate.endOfDay(FitnessDate.addingDays(previousDays - 1, to: previousStart))
        let range = period == .year
            ? "\(calendar.component(.year, from: currentStart))/\(FitnessDate.short(currentStart))–\(FitnessDate.short(currentEnd))"
            : "\(FitnessDate.short(currentStart))–\(FitnessDate.short(currentEnd))"
        return Bounds(
            currentStart: currentStart,
            currentEnd: currentEnd,
            previousStart: previousStart,
            previousEnd: previousEnd,
            periodDays: periodDays,
            previousDays: previousDays,
            rangeLabel: range
        )
    }

    private static func snapshot(
        store: AppStore,
        start: Date,
        end: Date,
        days: Int,
        targets: NutritionTargets,
        fallbackBody: Bool
    ) -> ReviewSnapshot {
        let sessions = store.sessions.filter { $0.date >= start && $0.date <= end }
        let foodLogs = store.foodLogs.filter { $0.date >= start && $0.date <= end }
        let foodDays = Set(foodLogs.map { FitnessDate.key($0.date) })
        let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let sets = sessions.reduce(0) { $0 + $1.sets.filter(\.completed).count }
        let nutrition = foodLogs.reduce(into: (kcal: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0)) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
        }
        let loggedDays = foodDays.count
        let averageIntake = loggedDays > 0 ? nutrition.kcal / Double(loggedDays) : nil
        let calorieGap = averageIntake.map { Double(targets.kcal) - $0 }
        let body = store.bodyMetrics
            .filter { $0.date <= end }
            .sorted { $0.date > $1.date }
            .first
        let fallbackWeight = fallbackBody ? store.profile.weightKG : nil
        let fallbackFat = fallbackBody ? store.profile.bodyFatPCT : nil

        return ReviewSnapshot(
            sessions: sessions.sorted { $0.date > $1.date },
            minutes: minutes,
            volume: volume,
            sets: sets,
            trainingDays: Set(sessions.map { FitnessDate.key($0.date) }).count,
            loggedFoodDays: loggedDays,
            totalKcal: nutrition.kcal,
            totalProtein: nutrition.protein,
            totalCarbs: nutrition.carbs,
            totalFat: nutrition.fat,
            averageDailyMinutes: days > 0 ? Double(minutes) / Double(days) : 0,
            averageSessionMinutes: sessions.isEmpty ? 0 : Double(minutes) / Double(sessions.count),
            averageIntake: averageIntake,
            calorieGap: calorieGap,
            weight: body?.weightKG ?? fallbackWeight,
            bodyFat: body?.bodyFatPCT ?? fallbackFat
        )
    }

    private enum TrendMode {
        case higher
        case lower
        case closeness
        case goalWeight
    }

    private static func trend(
        current: Double?,
        previous: Double?,
        mode: TrendMode,
        digits: Int,
        unit: String,
        target: Double? = nil
    ) -> ReviewTrend {
        guard let current, let previous else {
            return ReviewTrend(direction: .flat, tone: .muted, text: "暂无上期数据")
        }
        let delta = current - previous
        let threshold = digits > 0 ? 0.05 : 0.5
        if abs(delta) < threshold {
            return ReviewTrend(direction: .flat, tone: .flat, text: "与上期持平")
        }
        let direction: ReviewTrend.Direction = delta > 0 ? .up : .down
        let tone: ReviewTrend.Tone
        switch mode {
        case .higher:
            tone = direction == .up ? .good : .bad
        case .lower:
            tone = direction == .down ? .good : .bad
        case .closeness:
            if let target {
                let currentDistance = abs(current - target)
                let previousDistance = abs(previous - target)
                tone = currentDistance < previousDistance ? .good : currentDistance > previousDistance ? .bad : .flat
            } else {
                tone = .flat
            }
        case .goalWeight:
            if let target, target > 0 {
                let currentDistance = abs(current - target)
                let previousDistance = abs(previous - target)
                tone = currentDistance < previousDistance ? .good : currentDistance > previousDistance ? .bad : .flat
            } else {
                tone = .flat
            }
        }
        let sign = delta > 0 ? "+" : "-"
        let text = "较上期 \(sign)\(format(abs(delta), digits: digits))\(unit)"
        return ReviewTrend(direction: direction, tone: tone, text: text)
    }

    private static func format(_ value: Double?, digits: Int = 0) -> String {
        guard let value else { return "—" }
        return format(value, digits: digits)
    }

    private static func format(_ value: Double, digits: Int = 0) -> String {
        if digits > 0 { return String(format: "%.\(digits)f", value) }
        return Int(value.rounded()).formatted()
    }
}
