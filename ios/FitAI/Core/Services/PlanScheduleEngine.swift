import Foundation

/// Validation errors for the training-date board.
enum PlanScheduleValidationError: Error, Equatable {
    case noPlan
    case missingWeek(Int)
    case tooManyDays(week: Int, limit: Int)
    case duplicateDates(week: Int)
    case notEnoughSlots(week: Int, slots: Int)

    var message: String {
        switch self {
        case .noPlan:
            return "当前没有训练计划"
        case .missingWeek(let week):
            return "第 \(week) 周日期不完整"
        case .tooManyDays(let week, let limit):
            return "第 \(week) 周最多选 \(limit) 天"
        case .duplicateDates(let week):
            return "第 \(week) 周有重复日期"
        case .notEnoughSlots(let week, let slots):
            return "第 \(week) 周只有 \(slots) 个训练位"
        }
    }
}

/// Pure scheduling rules shared by the app and unit tests.
///
/// The board edits a set of dates per plan week. Keeping the mapping here
/// avoids the old "compact every date into the earliest slots" behavior,
/// which moved following workouts whenever a middle day was deselected and
/// marked the last slot as skipped instead of the day the user removed.
enum PlanScheduleEngine {
    /// Timestamp used for last-write-wins schedule sync.
    ///
    /// A freshly fetched plan has no per-day `scheduleUpdatedAt`; falling back
    /// to `plan.updatedAt` would let a reinstall claim a newer timestamp than
    /// the server state and overwrite a repaired schedule. `createdAt` is the
    /// plan's real age, so an untouched local plan loses to newer server state.
    static func uploadTimestamp(for day: PlanDay, in plan: TrainingPlan) -> Date {
        day.scheduleUpdatedAt ?? plan.createdAt
    }

    /// Give server-generated days the dates implied by their week/weekday.
    /// Server serializers do not own schedule state, so without this a freshly
    /// generated plan has no dates until an editor save.
    static func seedDates(in plan: TrainingPlan) -> TrainingPlan {
        var current = plan
        for index in current.days.indices where current.days[index].date == nil {
            current.days[index].date = current.date(
                week: current.days[index].weekIndex,
                weekday: current.days[index].weekday
            )
        }
        return current
    }

    static func apply(
        to plan: TrainingPlan,
        selection: [Int: [Date]],
        now: Date = Date()
    ) -> Result<TrainingPlan, PlanScheduleValidationError> {
        guard !plan.days.isEmpty else { return .failure(.noPlan) }
        var current = plan
        let weeks = max(1, current.weeks)
        let planWeeklyDays = current.weeklyDays
            ?? max(1, current.days.count / weeks)
        let limit = max(1, min(7, planWeeklyDays))

        for week in 1...weeks {
            guard let dates = selection[week] else {
                return .failure(.missingWeek(week))
            }
            if dates.count > limit {
                return .failure(.tooManyDays(week: week, limit: limit))
            }
            if Set(dates.map { FitnessDate.key($0) }).count != dates.count {
                return .failure(.duplicateDates(week: week))
            }
        }

        for week in 1...weeks {
            let allIndices = current.days.indices
                .filter { current.days[$0].weekIndex == week }
                .sorted { left, right in
                    sortByScheduledDate(left, right, in: current)
                }
            // A workout explicitly added before its plan week (for example
            // "train back today" on the Sunday before week 1) is not on the
            // 7-column board. Preserve it instead of skipping it on save.
            let weekStart = current.date(week: week, weekday: 1) ?? .distantPast
            let early = allIndices.filter { index in
                guard let date = current.days[index].date else { return false }
                return date < weekStart
            }
            let indices = allIndices.filter { !early.contains($0) }
            let dates = (selection[week] ?? []).sorted()
            guard dates.count <= indices.count else {
                return .failure(.notEnoughSlots(week: week, slots: indices.count))
            }

            // Match dates the user kept to the days that already own them.
            // Active days go first so a duplicated date stays on the active
            // day instead of reviving a skipped one.
            let active = indices.filter { current.days[$0].skippedAt == nil }
            let skipped = indices.filter { current.days[$0].skippedAt != nil }
            var remaining = Set(dates.map { FitnessDate.key($0) })
            var assigned: [Int: Date] = [:]
            var unmatched: [Int] = []
            for index in active + skipped {
                guard let date = current.days[index].date else {
                    unmatched.append(index)
                    continue
                }
                let key = FitnessDate.key(date)
                if remaining.contains(key) {
                    assigned[index] = FitnessDate.startOfDay(date)
                    remaining.remove(key)
                } else {
                    unmatched.append(index)
                }
            }

            // Newly selected dates fill skipped days first, so re-adding a
            // date restores it; otherwise they move the days that lost a date.
            let newDates = dates.filter { remaining.contains(FitnessDate.key($0)) }
            let orderedUnmatched = unmatched.sorted { left, right in
                let leftSkipped = current.days[left].skippedAt != nil
                let rightSkipped = current.days[right].skippedAt != nil
                if leftSkipped != rightSkipped { return leftSkipped }
                return sortByScheduledDate(left, right, in: current)
            }
            for (offset, date) in newDates.enumerated() where offset < orderedUnmatched.count {
                assigned[orderedUnmatched[offset]] = date
            }

            for index in indices {
                if let date = assigned[index] {
                    current.days[index].date = FitnessDate.startOfDay(date)
                    current.days[index].weekday = FitnessDate.weekdayNumber(date)
                    current.days[index].skippedAt = nil
                    current.days[index].scheduleUpdatedAt = now
                } else {
                    // A skipped workout has no scheduled date. Keeping the
                    // old date is what produced two entries on the same day.
                    if current.days[index].skippedAt == nil {
                        current.days[index].skippedAt = now
                        current.days[index].scheduleUpdatedAt = now
                    }
                    if current.days[index].date != nil {
                        current.days[index].date = nil
                        current.days[index].scheduleUpdatedAt = now
                    }
                }
            }
        }

        current.days.sort { left, right in
            if left.weekIndex != right.weekIndex { return left.weekIndex < right.weekIndex }
            let leftDate = left.date ?? .distantFuture
            let rightDate = right.date ?? .distantFuture
            if leftDate != rightDate { return leftDate < rightDate }
            if left.weekday != right.weekday { return left.weekday < right.weekday }
            return left.id.uuidString < right.id.uuidString
        }
        current.updatedAt = now
        return .success(current)
    }

    private static func sortByScheduledDate(
        _ left: Int,
        _ right: Int,
        in plan: TrainingPlan
    ) -> Bool {
        let leftDate = plan.scheduledDate(for: plan.days[left]) ?? .distantFuture
        let rightDate = plan.scheduledDate(for: plan.days[right]) ?? .distantFuture
        if leftDate != rightDate { return leftDate < rightDate }
        if plan.days[left].weekday != plan.days[right].weekday {
            return plan.days[left].weekday < plan.days[right].weekday
        }
        return plan.days[left].id.uuidString < plan.days[right].id.uuidString
    }
}
