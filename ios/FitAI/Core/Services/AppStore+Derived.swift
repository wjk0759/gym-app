import Foundation

extension AppStore {
    // MARK: - Derived state

    var currentPlanWeek: Int {
        guard let plan else { return 1 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return 1
        }
        let now = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: planMonday, to: now).day ?? 0
        return min(max(1, days / 7 + 1), max(1, plan.weeks))
    }

    var currentPlanWeekInterval: DateInterval? {
        guard let plan else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start),
              let weekStart = calendar.date(
                byAdding: .day,
                value: (currentPlanWeek - 1) * 7,
                to: planMonday
              ),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return nil
        }
        return DateInterval(start: weekStart, end: weekEnd)
    }

    var isPlanFinished: Bool {
        guard let plan else { return false }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: plan.createdAt)
        let startWeekday = calendar.component(.weekday, from: start)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        guard let planMonday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return false
        }
        let days = calendar.dateComponents(
            [.day],
            from: planMonday,
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        return days >= plan.weeks * 7
    }

    var todayDay: PlanDay? {
        guard let plan else { return nil }
        if let scheduled = plan.day(on: Date()) {
            return scheduled
        }
        if plan.days.contains(where: { $0.date != nil }) {
            return nil
        }
        return plan.weekDays(in: currentPlanWeek).first { $0.weekday == Weekday.today }
    }

    var currentWeekSessions: [WorkoutSession] {
        if let interval = currentPlanWeekInterval {
            return sessions.filter { interval.contains($0.date) }
        }
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return sessions
        }
        return sessions.filter { interval.contains($0.date) }
    }

    var currentWeekPlannedCount: Int {
        guard let plan else { return max(1, profile.weeklyDays) }
        return plan.weekDays(in: currentPlanWeek).count
    }

    /// 计划日维度真正完成的次数；练了一半不算完成一次。
    var currentWeekCompletedCount: Int {
        guard let plan else { return currentWeekSessions.count }
        return plan.weekDays(in: currentPlanWeek).filter { isPlanDayCompleted($0) }.count
    }

    var weeklyCompletion: Double {
        guard let plan else {
            let planned = currentWeekPlannedCount
            guard planned > 0 else { return 0 }
            return min(1.0, Double(currentWeekSessions.count) / Double(planned))
        }
        let days = plan.weekDays(in: currentPlanWeek)
        guard !days.isEmpty else { return 0 }
        let progress = days.reduce(0.0) { partial, day in
            partial + planDayProgress(day)
        }
        return min(1.0, progress / Double(days.count))
    }

    var totalVolume: Double {
        sessions.reduce(0) { $0 + $1.volume }
    }

    var todayFoodLogs: [FoodLog] {
        foodLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todayNutrition: NutritionTotals {
        todayFoodLogs.reduce(into: NutritionTotals()) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
            total.fiber += log.fiber ?? 0
        }
    }

    var recentAverageRPE: Double {
        let recentSets = sessions.prefix(3).flatMap { $0.sets }.filter { $0.completed }
        guard !recentSets.isEmpty else { return 0 }
        return recentSets.reduce(0.0) { $0 + $1.rpe } / Double(recentSets.count)
    }

    /// 本周 RPE，和“本周完成率”使用同一个时间窗口，复盘时更一致。
    var currentWeekAverageRPE: Double {
        let sets = currentWeekSessions.prefix(3).flatMap { $0.sets }.filter { $0.completed }
        guard !sets.isEmpty else { return 0 }
        return sets.reduce(0.0) { $0 + $1.rpe } / Double(sets.count)
    }

    var currentWeekVolume: Double {
        currentWeekSessions.reduce(0) { $0 + $1.volume }
    }

    var canUseRemoteAI: Bool {
        useRemoteAI && (isPro || debugForceRemoteAI)
    }

    var planAdjustmentPreview: PlanGenerator.Adjustment {
        PlanGenerator.adjustment(
            completionRate: weeklyCompletion,
            averageRPE: currentWeekAverageRPE
        )
    }

    var equipmentSlugsForPlan: [String] {
        guard useEquipmentLibraryForPlans else { return [] }
        return equipmentLibrary.compactMap(\.slug).filter { slug in
            guard let exercise = ExerciseLibrary.exercise(slug: slug) else { return false }
            return profile.equipment.contains(exercise.equipment)
        }
    }
}
