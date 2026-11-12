import Foundation

struct PlanAdherence: Equatable {
    let plannedDays: Int
    let completedDays: Int
    let skippedDays: Int
    let missedDays: Int

    /// Skipped days are a deliberate decision, not a failed workout, so they do
    /// not count against the adherence denominator.
    var eligibleDays: Int { max(0, plannedDays - skippedDays) }

    var rate: Double? {
        guard eligibleDays > 0 else { return nil }
        return min(1, Double(completedDays) / Double(eligibleDays))
    }

    var percentText: String {
        guard let rate else { return "—" }
        return "\(Int((rate * 100).rounded()))"
    }
}

struct ReviewNextAction: Equatable {
    enum Kind: Equatable {
        case training
        case plan
        case nutrition
    }

    let kind: Kind
    let title: String
    let detail: String
}

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
    let totalFiber: Double
    let averageDailyMinutes: Double
    let averageSessionMinutes: Double
    let averageRPE: Double?
    let averageIntake: Double?
    let calorieGap: Double?
    let weight: Double?
    let bodyFat: Double?
    let adherence: PlanAdherence

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
    let nextAction: ReviewNextAction?
}

struct ReviewInput {
    let sessions: [WorkoutSession]
    let foodLogs: [FoodLog]
    let bodyMetrics: [BodyMetric]
    let profile: UserProfile
    let plan: TrainingPlan?

    init(
        sessions: [WorkoutSession],
        foodLogs: [FoodLog],
        bodyMetrics: [BodyMetric],
        profile: UserProfile,
        plan: TrainingPlan?
    ) {
        self.sessions = sessions
        self.foodLogs = foodLogs
        self.bodyMetrics = bodyMetrics
        self.profile = profile
        self.plan = plan
    }

    init(store: AppStore) {
        sessions = store.sessions
        foodLogs = store.foodLogs
        bodyMetrics = store.bodyMetrics
        profile = store.profile
        plan = store.plan
    }
}

enum PlanReviewEngine {
    static func make(input: ReviewInput, period: ReviewPeriod, now: Date = Date()) -> ReviewData {
        let bounds = bounds(for: period, now: now)
        let targets = DietPlanner.targets(profile: input.profile)
        let current = snapshot(
            input: input,
            start: bounds.currentStart,
            end: bounds.currentEnd,
            days: bounds.periodDays,
            targets: targets,
            fallbackBody: true,
            now: now
        )
        let previous = snapshot(
            input: input,
            start: bounds.previousStart,
            end: bounds.previousEnd,
            days: bounds.previousDays,
            targets: targets,
            fallbackBody: false,
            now: now
        )
        let currentGap = current.calorieGap
        let previousGap = previous.calorieGap

        let trends: [String: ReviewTrend] = [
            "sessions": trend(current: Double(current.sessions.count), previous: Double(previous.sessions.count), mode: .higher, digits: 0, unit: " 次"),
            "adherence": trend(
                current: current.adherence.rate.map { $0 * 100 },
                previous: previous.adherence.rate.map { $0 * 100 },
                mode: .higher,
                digits: 0,
                unit: "%"
            ),
            "duration": trend(current: current.averageDailyMinutes, previous: previous.averageDailyMinutes, mode: .higher, digits: 1, unit: " 分钟"),
            "intake": trend(current: current.averageIntake, previous: previous.averageIntake, mode: .closeness, digits: 0, unit: " kcal", target: Double(targets.kcal)),
            "deficit": trend(current: currentGap, previous: previousGap, mode: .closeness, digits: 0, unit: " kcal", target: 0),
            "weight": trend(current: current.weight, previous: previous.weight, mode: .goalWeight, digits: 1, unit: " kg", target: input.profile.targetWeightKG),
            "bodyFat": trend(current: current.bodyFat, previous: previous.bodyFat, mode: .lower, digits: 1, unit: "%")
        ]

        let kpis: [ReviewKPI] = [
            ReviewKPI(
                id: "adherence",
                label: "计划完成率",
                display: current.adherence.percentText,
                unit: current.adherence.rate == nil ? "" : "%",
                previousDisplay: previous.adherence.rate.map {
                    "\(Int(($0 * 100).rounded()))%"
                } ?? "—",
                trend: trends["adherence"]!,
                note: current.adherence.plannedDays > 0
                    ? "完成 \(current.adherence.completedDays)/\(current.adherence.eligibleDays) 个计划日 · 跳过 \(current.adherence.skippedDays)"
                    : "当前计划未覆盖本期"
            ),
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
                note: input.profile.targetWeightKG > 0 ? "目标 \(format(input.profile.targetWeightKG, digits: 1)) kg" : "未设目标"
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
            periodDays: bounds.periodDays,
            nextAction: nextAction(
                current: current,
                profile: input.profile,
                targets: targets
            )
        )
    }

    /// One next step, chosen by the same deterministic rules the server review
    /// uses. Training lapses take priority over nutrition logging because they
    /// change the next scheduled session.
    private static func nextAction(
        current: ReviewSnapshot,
        profile: UserProfile,
        targets: NutritionTargets
    ) -> ReviewNextAction? {
        let adherence = current.adherence

        if adherence.missedDays > 0 {
            let minutes = max(20, profile.sessionMinutes)
            return ReviewNextAction(
                kind: .training,
                title: "先补一次错过的训练",
                detail: "本期有 \(adherence.missedDays) 次计划训练未完成。接下来 48 小时安排一次 \(minutes) 分钟训练，优先保留主项，不必加倍补课。"
            )
        }

        if current.sessions.isEmpty {
            let minutes = max(20, profile.sessionMinutes)
            return ReviewNextAction(
                kind: .training,
                title: "先完成一次训练",
                detail: "本期还没有训练记录。今天或明天做一次 \(minutes) 分钟的全身训练，把节奏找回来。"
            )
        }

        if let rate = adherence.rate, rate < 0.6, adherence.plannedDays >= 3 {
            let achievable = max(2, current.sessions.count)
            return ReviewNextAction(
                kind: .plan,
                title: "把计划降到做得到的频率",
                detail: "本期完成 \(adherence.completedDays)/\(adherence.eligibleDays) 个计划日。先让教练把每周训练改成 \(achievable) 次，稳定两周再增加。"
            )
        }

        if let averageRPE = current.averageRPE, averageRPE >= 8.5 {
            return ReviewNextAction(
                kind: .training,
                title: "下一次先降一点强度",
                detail: "本期平均 RPE \(String(format: "%.1f", averageRPE))，恢复压力偏高。同动作降 1 组或降 5% 重量，把 RPE 控制在 7–8。"
            )
        }

        if current.loggedFoodDays < 3 {
            return ReviewNextAction(
                kind: .nutrition,
                title: "每天至少记录一餐",
                detail: "本期只有 \(current.loggedFoodDays) 天有饮食记录。先拍照记录主餐，才能判断 \(targets.kcal) kcal 的目标是否需要调整。"
            )
        }

        return ReviewNextAction(
            kind: .training,
            title: "保持频率，下一次加一点",
            detail: "计划完成稳定。下一次主力动作在动作不变形时加 2.5% 重量或每组多做 1 次。"
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
        input: ReviewInput,
        start: Date,
        end: Date,
        days: Int,
        targets: NutritionTargets,
        fallbackBody: Bool,
        now: Date
    ) -> ReviewSnapshot {
        let sessions = input.sessions.filter { $0.date >= start && $0.date <= end }
        let foodLogs = input.foodLogs.filter { $0.date >= start && $0.date <= end }
        let foodDays = Set(foodLogs.map { FitnessDate.key($0.date) })
        let minutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        let volume = sessions.reduce(0) { $0 + $1.volume }
        let completedSets = sessions.flatMap(\.sets).filter(\.completed)
        let sets = completedSets.count
        let averageRPE = completedSets.isEmpty
            ? nil
            : completedSets.reduce(0) { $0 + $1.rpe } / Double(completedSets.count)
        let adherence = planAdherence(
            plan: input.plan,
            sessions: input.sessions,
            start: start,
            end: end,
            now: now
        )
        let nutrition = foodLogs.reduce(into: (kcal: 0.0, protein: 0.0, carbs: 0.0, fat: 0.0, fiber: 0.0)) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
            total.fiber += log.fiber ?? 0
        }
        let loggedDays = foodDays.count
        let averageIntake = loggedDays > 0 ? nutrition.kcal / Double(loggedDays) : nil
        let calorieGap = averageIntake.map { Double(targets.kcal) - $0 }
        let body = input.bodyMetrics
            .filter { $0.date <= end }
            .sorted { $0.date > $1.date }
            .first
        let fallbackWeight = fallbackBody ? input.profile.weightKG : nil
        let fallbackFat = fallbackBody ? input.profile.bodyFatPCT : nil

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
            totalFiber: nutrition.fiber,
            averageDailyMinutes: days > 0 ? Double(minutes) / Double(days) : 0,
            averageSessionMinutes: sessions.isEmpty ? 0 : Double(minutes) / Double(sessions.count),
            averageRPE: averageRPE,
            averageIntake: averageIntake,
            calorieGap: calorieGap,
            weight: body?.weightKG ?? fallbackWeight,
            bodyFat: body?.bodyFatPCT ?? fallbackFat,
            adherence: adherence
        )
    }

    // MARK: - Plan adherence

    private static func planAdherence(
        plan: TrainingPlan?,
        sessions: [WorkoutSession],
        start: Date,
        end: Date,
        now: Date
    ) -> PlanAdherence {
        guard let plan else {
            return PlanAdherence(plannedDays: 0, completedDays: 0, skippedDays: 0, missedDays: 0)
        }
        var planned = 0
        var completed = 0
        var skipped = 0
        var missed = 0

        for day in plan.days {
            guard let scheduled = plan.scheduledDate(for: day),
                  scheduled >= start,
                  scheduled <= end else { continue }
            planned += 1
            let wasSkipped = day.skippedAt != nil
            if wasSkipped {
                skipped += 1
                continue
            }
            if isPlanDayCompleted(day, plan: plan, sessions: sessions) {
                completed += 1
            } else if FitnessDate.endOfDay(scheduled) < now {
                missed += 1
            }
        }
        return PlanAdherence(
            plannedDays: planned,
            completedDays: completed,
            skippedDays: skipped,
            missedDays: missed
        )
    }

    private static func isPlanDayCompleted(
        _ day: PlanDay,
        plan: TrainingPlan,
        sessions: [WorkoutSession]
    ) -> Bool {
        let plannedSets = max(
            1,
            day.exercises.reduce(0) { $0 + max(1, $1.sets) }
        )
        let matching = sessions.filter { session in
            if session.programDayID == day.id.uuidString {
                return true
            }
            guard session.programDayID == nil,
                  let scheduled = plan.scheduledDate(for: day) else { return false }
            return session.dayTitle == day.title
                && FitnessDate.calendar.isDate(session.date, inSameDayAs: scheduled)
        }
        let effectivePlanned = max(
            plannedSets,
            matching.compactMap(\.plannedSets).max() ?? 0
        )
        let completedSets = matching.reduce(0) {
            $0 + $1.sets.filter(\.completed).count
        }
        return completedSets >= effectivePlanned
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
