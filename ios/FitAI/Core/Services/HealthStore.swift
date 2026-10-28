import Foundation

// MARK: - Body, goal and period state

extension AppStore {
    var latestBodyMetric: BodyMetric? {
        bodyMetrics.sorted { $0.date > $1.date }.first
    }

    var hasPlanEquipment: Bool {
        profile.equipment.contains { equipment in
            ExerciseLibrary.all.contains { exercise in
                exercise.equipment == equipment && exercise.muscle != .cardio
            }
        }
    }

    func seedBodyMetricsIfNeeded() {
        guard bodyMetrics.isEmpty else { return }
        bodyMetrics = [
            BodyMetric(
                date: FitnessDate.addingDays(-1, to: FitnessDate.startOfDay(Date())),
                weightKG: profile.weightKG,
                bodyFatPCT: profile.bodyFatPCT,
                waistCM: profile.waistCM,
                armCM: profile.armCM,
                thighCM: profile.thighCM
            )
        ]
    }

    func normalizeGoalStart(_ profile: inout UserProfile) {
        if profile.goalStartWeight == nil || (profile.goalStartWeight ?? 0) <= 0 {
            profile.goalStartWeight = bodyMetrics.last?.weightKG ?? profile.weightKG
        }
        if profile.goalStartDate == nil {
            profile.goalStartDate = bodyMetrics.last?.date ?? Date()
        }
    }

    /// Appends or replaces the metric for the same calendar day.
    /// Callers persist after updating the related profile fields.
    func appendBodyMetric(_ metric: BodyMetric) {
        var value = metric
        value.date = FitnessDate.startOfDay(value.date)
        let key = value.dateKey
        bodyMetrics.removeAll { $0.dateKey == key }
        bodyMetrics.append(value)
        bodyMetrics.sort { $0.date > $1.date }
        profile.weightKG = value.weightKG
        profile.bodyFatPCT = value.bodyFatPCT
        profile.waistCM = value.waistCM
        if let arm = value.armCM, arm > 0 { profile.armCM = arm }
        if let thigh = value.thighCM, thigh > 0 { profile.thighCM = thigh }
        if profile.goalStartWeight == nil || (profile.goalStartWeight ?? 0) <= 0 {
            profile.goalStartWeight = value.weightKG
            profile.goalStartDate = value.date
        }
        bodyCheckInDismissedDate = key
    }

    @discardableResult
    func saveBodyCheckIn(weightKG: Double, bodyFatPCT: Double, waistCM: Double) -> BodyMetric {
        let metric = BodyMetric(
            date: Date(),
            weightKG: (weightKG * 10).rounded() / 10,
            bodyFatPCT: (bodyFatPCT * 10).rounded() / 10,
            waistCM: (waistCM * 10).rounded() / 10,
            armCM: profile.armCM,
            thighCM: profile.thighCM
        )
        appendBodyMetric(metric)
        persist()
        syncPendingUserData()
        return metric
    }

    func removeBodyMetric(id: UUID) {
        guard let index = bodyMetrics.firstIndex(where: { $0.id == id }) else {
            return
        }
        bodyMetrics.remove(at: index)
        if let latest = bodyMetrics.sorted(by: { $0.date > $1.date }).first {
            profile.weightKG = latest.weightKG
            profile.bodyFatPCT = latest.bodyFatPCT
            profile.waistCM = latest.waistCM
        }
        persist()
        Task {
            try? await APIClient.shared.deleteBodyMetric(id: id)
        }
        syncPendingUserData()
    }

    func dismissBodyCheckIn() {
        bodyCheckInDismissedDate = FitnessDate.key(Date())
        persist()
    }

    func disableBodyCheckIn() {
        bodyCheckInFrequency = .off
        bodyCheckInDismissedDate = FitnessDate.key(Date())
        persist()
    }

    func setBodyCheckInFrequency(_ frequency: BodyCheckInFrequency) {
        bodyCheckInFrequency = frequency
        bodyCheckInAnchor = FitnessDate.monday(of: Date())
        bodyCheckInDismissedDate = nil
        persist()
    }

    func setBodyCheckInWeekday(_ weekday: Int) {
        bodyCheckInWeekday = min(max(weekday, 1), 7)
        bodyCheckInAnchor = FitnessDate.monday(of: Date())
        persist()
    }

    func setBodyCheckInDay(_ day: Int) {
        bodyCheckInDay = min(max(day, 1), 28)
        persist()
    }

    var bodyCheckInFrequencyLabel: String {
        switch bodyCheckInFrequency {
        case .off: return "已关闭"
        case .weekly: return "每周\(Weekday.shortNames[max(0, min(6, bodyCheckInWeekday - 1))])"
        case .biweekly: return "每两周 · 周\(Weekday.shortNames[max(0, min(6, bodyCheckInWeekday - 1))])"
        case .monthly: return "每月 \(bodyCheckInDay) 日"
        }
    }

    var bodyCheckInDue: Bool {
        guard bodyCheckInFrequency != .off else { return false }
        let today = Date()
        let key = FitnessDate.key(today)
        guard bodyCheckInDismissedDate != key else { return false }
        guard !bodyMetrics.contains(where: { $0.dateKey == key }) else { return false }

        switch bodyCheckInFrequency {
        case .off:
            return false
        case .weekly:
            return FitnessDate.weekdayNumber(today) == bodyCheckInWeekday
        case .biweekly:
            guard FitnessDate.weekdayNumber(today) == bodyCheckInWeekday else { return false }
            let anchor = FitnessDate.monday(of: bodyCheckInAnchor)
            let current = FitnessDate.monday(of: today)
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: anchor, to: current).weekOfYear ?? 0
            return abs(weeks) % 2 == 0
        case .monthly:
            return FitnessDate.calendar.component(.day, from: today) == bodyCheckInDay
        }
    }

    var goalProgress: GoalProgress {
        let metrics = bodyMetrics.sorted { $0.date > $1.date }
        let currentWeight = metrics.first?.weightKG ?? profile.weightKG
        let startWeight = profile.goalStartWeight
            ?? metrics.last?.weightKG
            ?? profile.weightKG
        let target = profile.targetWeightKG
        let denominator = target - startWeight
        let rawProgress: Double
        if abs(denominator) < 0.05 {
            rawProgress = abs(currentWeight - target) < 0.05 ? 100 : 0
        } else {
            rawProgress = ((currentWeight - startWeight) / denominator) * 100
        }
        let calendar = FitnessDate.calendar
        let today = FitnessDate.startOfDay(Date())
        let targetDate = FitnessDate.startOfDay(profile.targetDate)
        let daysLeft = calendar.dateComponents([.day], from: today, to: targetDate).day
        let currentWaist = metrics.first?.waistCM ?? profile.waistCM
        let currentBodyFat = metrics.first?.bodyFatPCT ?? profile.bodyFatPCT
        let targetWaist = (profile.goalType == .endurance ? nil : profile.targetWaistCM)
        let targetBodyFat = (profile.goalType == .endurance ? nil : profile.targetBodyFatPCT)

        return GoalProgress(
            startWeight: startWeight,
            currentWeight: currentWeight,
            targetWeight: target,
            progress: Int(max(0, min(100, rawProgress.rounded()))),
            distance: target > 0 ? abs(target - currentWeight) : nil,
            targetDate: targetDate,
            daysLeft: daysLeft,
            hasTodayMetric: metrics.contains { $0.dateKey == FitnessDate.key(today) },
            currentWaist: currentWaist,
            currentBodyFat: currentBodyFat,
            targetWaist: targetWaist,
            targetBodyFat: targetBodyFat
        )
    }

    // MARK: - Period

    func periodDay(for date: Date) -> PeriodDay? {
        guard profile.sex == .female else { return nil }
        let key = FitnessDate.key(date)
        guard profile.periodDates.contains(key) else { return nil }
        var day = 1
        var cursor = FitnessDate.addingDays(-1, to: FitnessDate.startOfDay(date))
        while day < 60 && profile.periodDates.contains(FitnessDate.key(cursor)) {
            day += 1
            cursor = FitnessDate.addingDays(-1, to: cursor)
        }
        return PeriodDay(
            day: day,
            dateKey: key,
            mode: profile.periodTrainingMode
        )
    }

    var todayPeriod: PeriodDay? {
        periodDay(for: Date())
    }

    func isPeriodDate(_ date: Date) -> Bool {
        periodDay(for: date) != nil
    }

    @discardableResult
    func savePeriodRange(startKey: String, endKey: String, mode: PeriodTrainingMode) -> Bool {
        guard profile.sex == .female,
              let start = FitnessDate.date(from: startKey),
              let end = FitnessDate.date(from: endKey) else { return false }
        let rangeStart = min(start, end)
        let rangeEnd = max(start, end)
        var dates: [String] = []
        var cursor = FitnessDate.startOfDay(rangeStart)
        let last = FitnessDate.startOfDay(rangeEnd)
        var guardCount = 0
        while cursor <= last && guardCount < 90 {
            dates.append(FitnessDate.key(cursor))
            cursor = FitnessDate.addingDays(1, to: cursor)
            guardCount += 1
        }
        guard !dates.isEmpty, guardCount < 90 else { return false }
        profile.periodRangeStart = FitnessDate.key(rangeStart)
        profile.periodRangeEnd = FitnessDate.key(rangeEnd)
        profile.periodDates = dates
        profile.periodTrainingMode = mode
        toast = "经期区间已保存"
        persist()
        return true
    }

    // MARK: - Plan schedule

    func applyPlanSchedule(_ selection: [Int: [Date]]) -> Bool {
        guard var current = plan else { return false }
        let now = Date()
        let target = max(1, min(7, profile.weeklyDays))
        for week in 1...current.weeks {
            guard let dates = selection[week],
                  dates.count <= target,
                  Set(dates).count == dates.count else {
                return false
            }
        }
        for week in 1...current.weeks {
            let indices = current.days.indices
                .filter { current.days[$0].weekIndex == week }
                .sorted {
                    let left = current.scheduledDate(for: current.days[$0]) ?? .distantFuture
                    let right = current.scheduledDate(for: current.days[$1]) ?? .distantFuture
                    return left < right
                }
            let dates = (selection[week] ?? []).sorted()
            guard dates.count <= indices.count else { return false }
            for (slot, index) in indices.enumerated() {
                if slot < dates.count {
                    current.days[index].date = FitnessDate.startOfDay(dates[slot])
                    current.days[index].weekday = FitnessDate.weekdayNumber(dates[slot])
                    current.days[index].skippedAt = nil
                    current.days[index].scheduleUpdatedAt = now
                } else if current.days[index].skippedAt == nil {
                    // 用户主动少选的天数标记为跳过，不进入今日卡和通知。
                    current.days[index].skippedAt = now
                    current.days[index].scheduleUpdatedAt = now
                }
            }
        }
        current.days.sort {
            if $0.weekIndex != $1.weekIndex { return $0.weekIndex < $1.weekIndex }
            let left = $0.date ?? .distantFuture
            let right = $1.date ?? .distantFuture
            return left == right ? $0.weekday < $1.weekday : left < right
        }
        current.version += 1
        current.updatedAt = now
        plan = current
        toast = "训练日期已更新"
        persist()
        rescheduleNotifications()
        syncPendingUserData()
        return true
    }

    // MARK: - Flexible rescheduling

    /// 与某个计划日关联的训练记录。新记录用 programDayID；
    /// 旧记录或旧版临时 programDayID 不属于当前计划时，用“同一天 + 同一标题”兜底。
    func planDaySessions(_ day: PlanDay) -> [WorkoutSession] {
        let dayID = day.id.uuidString
        let scheduled = plan?.scheduledDate(for: day)
        let currentPlanDayIDs = Set(plan?.days.map { $0.id.uuidString } ?? [])
        return sessions.filter { session in
            if session.programDayID == dayID { return true }
            // 旧版“今日训练编排”会生成临时 programDayID；它不属于任何当前计划日时，
            // 仍用同一天 + 同一标题匹配，避免完成训练后首页继续提示开始训练。
            if let programDayID = session.programDayID,
               currentPlanDayIDs.contains(programDayID) {
                return false
            }
            guard let scheduled else { return false }
            return session.dayTitle == day.title
                && FitnessDate.calendar.isDate(session.date, inSameDayAs: scheduled)
        }
    }

    /// 这次训练计划的组数。优先用训练记录/草稿里保存的实际计划组数，
    /// 这样经期轻量版少做一组也不会被误判成“没练完”。
    func plannedSets(for day: PlanDay) -> Int {
        let planSets = day.exercises.reduce(0) { partial, exercise in
            partial + max(1, exercise.sets)
        }
        let draftSets = workoutDraft?.dayID == day.id ? workoutDraft?.plannedSets : nil
        let recordedSets = planDaySessions(day).compactMap(\.plannedSets).max()
        let effectiveSets = draftSets ?? recordedSets ?? planSets
        return max(1, effectiveSets)
    }

    /// 已经正式保存的训练记录里完成了多少组。
    func finalizedCompletedSets(for day: PlanDay) -> Int {
        planDaySessions(day).reduce(0) { partial, session in
            partial + session.sets.filter(\.completed).count
        }
    }

    /// 当前训练草稿里完成了多少组。
    func draftCompletedSets(for day: PlanDay) -> Int {
        guard workoutDraft?.dayID == day.id, let draft = workoutDraft else { return 0 }
        return draft.logs.filter(\.completed).count
    }

    /// 展示用完成组数 = 已保存记录 + 当前未结束草稿。
    func completedSets(for day: PlanDay) -> Int {
        finalizedCompletedSets(for: day) + draftCompletedSets(for: day)
    }

    func planDayProgress(_ day: PlanDay) -> Double {
        let planned = plannedSets(for: day)
        guard planned > 0 else { return 0 }
        return min(1, Double(completedSets(for: day)) / Double(planned))
    }

    /// 只有正式保存且覆盖了计划组数，才算完成整个训练日。
    /// 练了一半、暂停中的草稿都不算完成。
    func isPlanDayCompleted(_ day: PlanDay) -> Bool {
        let planned = plannedSets(for: day)
        guard planned > 0 else { return false }
        return finalizedCompletedSets(for: day) >= planned
    }

    /// 已经过期、没有完成、也没有明确跳过的训练。只回溯 28 天，避免一次显示太多陈年欠账。
    var missedPlanDays: [PlanDay] {
        guard let plan else { return [] }
        let today = FitnessDate.startOfDay(Date())
        let cutoff = FitnessDate.addingDays(-28, to: today)
        return plan.days
            .filter { day in
                guard day.skippedAt == nil,
                      workoutDraft?.dayID != day.id,
                      !isPlanDayCompleted(day),
                      let date = plan.scheduledDate(for: day) else { return false }
                let dayStart = FitnessDate.startOfDay(date)
                return dayStart < today && dayStart >= cutoff
            }
            .sorted {
                (plan.scheduledDate(for: $0) ?? .distantFuture)
                    < (plan.scheduledDate(for: $1) ?? .distantFuture)
            }
    }

    /// 从指定日期之后寻找第一个没有安排训练的空档；已跳过的日期视为空档。
    func nextFreePlanDate(after date: Date, excluding dayID: UUID? = nil) -> Date? {
        guard let plan else { return nil }
        var cursor = FitnessDate.addingDays(
            1,
            to: FitnessDate.startOfDay(date)
        )
        let occupied = Set(
            plan.days
                .filter { $0.id != dayID && $0.skippedAt == nil }
                .compactMap { plan.scheduledDate(for: $0) }
                .map { FitnessDate.key($0) }
        )
        for _ in 0..<90 {
            if !occupied.contains(FitnessDate.key(cursor)) {
                return cursor
            }
            cursor = FitnessDate.addingDays(1, to: cursor)
        }
        return nil
    }

    @discardableResult
    func deferPlanDay(_ day: PlanDay) -> Bool {
        guard !isPlanDayCompleted(day) else {
            toast = "这次训练已经完成，不需要顺延"
            return false
        }
        guard let target = nextFreePlanDate(after: Date(), excluding: day.id) else {
            toast = "未来 90 天没有可用空档，可以选择跳过这次"
            return false
        }
        return movePlanDay(day.id, to: target)
    }

    @discardableResult
    func skipPlanDay(_ day: PlanDay) -> Bool {
        guard !isPlanDayCompleted(day) else {
            toast = "这次训练已经完成，不能跳过"
            return false
        }
        guard var current = plan,
              let index = current.days.firstIndex(where: { $0.id == day.id }) else {
            return false
        }
        let now = Date()
        current.days[index].skippedAt = now
        current.days[index].scheduleUpdatedAt = now
        current.version += 1
        current.updatedAt = now
        plan = current
        toast = "已跳过这次训练，不会算作未完成"
        persist()
        rescheduleNotifications()
        syncPendingUserData()
        return true
    }

    @discardableResult
    func reschedulePlanDay(_ day: PlanDay, to date: Date) -> Bool {
        movePlanDay(day.id, to: date)
    }

    private func movePlanDay(_ dayID: UUID, to date: Date) -> Bool {
        guard var current = plan,
              let index = current.days.firstIndex(where: { $0.id == dayID }) else {
            return false
        }
        let now = Date()
        let target = FitnessDate.startOfDay(date)
        let occupied = current.days.contains { item in
            item.id != dayID
                && item.skippedAt == nil
                && current.scheduledDate(for: item).map {
                    FitnessDate.calendar.isDate($0, inSameDayAs: target)
                } == true
        }
        guard !occupied else {
            toast = "那天已经有训练，请选择其他空档"
            return false
        }

        let targetWeek = weekIndex(for: target, in: current)
        current.days[index].date = target
        current.days[index].weekday = FitnessDate.weekdayNumber(target)
        current.days[index].weekIndex = targetWeek
        current.days[index].skippedAt = nil
        current.days[index].scheduleUpdatedAt = now
        current.weeks = max(current.weeks, targetWeek)
        current.version += 1
        current.updatedAt = now
        plan = current
        toast = "已改到 \(FitnessDate.short(target))"
        persist()
        rescheduleNotifications()
        syncPendingUserData()
        return true
    }

    private func weekIndex(for date: Date, in plan: TrainingPlan) -> Int {
        guard let start = plan.date(week: 1, weekday: 1) else { return 1 }
        let diff = FitnessDate.calendar.dateComponents(
            [.day],
            from: start,
            to: FitnessDate.startOfDay(date)
        ).day ?? 0
        return max(1, diff / 7 + 1)
    }
}
