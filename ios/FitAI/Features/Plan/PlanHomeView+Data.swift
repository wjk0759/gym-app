import SwiftUI

extension PlanHomeView {
    // MARK: - Dates

    var calendarDays: [Date] {
        let monthStart = startOfMonth(visibleMonth)
        let weekday = calendar.component(.weekday, from: monthStart)
        let mondayOffset = (weekday + 5) % 7
        guard let gridStart = calendar.date(
            byAdding: .day,
            value: -mondayOffset,
            to: monthStart
        ) else {
            return []
        }
        return (0..<42).compactMap {
            calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
    }

    func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// Consume the one-shot handoff from Today and focus the matching day.
    func consumePendingRecordDate() {
        guard let date = store.pendingRecordDate else { return }
        store.pendingRecordDate = nil
        focusOnRecordDate(date)
    }

    func focusOnRecordDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        visibleMonth = startOfMonth(day)
        dayScrollRequest += 1
    }

    func mondayOfWeek(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let offset = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: start) ?? start
    }

    func shiftMonth(_ amount: Int) {
        guard let next = calendar.date(
            byAdding: .month,
            value: amount,
            to: startOfMonth(visibleMonth)
        ) else {
            return
        }
        visibleMonth = next
        selectedDate = next
    }

    func goToToday() {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        visibleMonth = startOfMonth(today)
    }

    func dayEyebrow(_ date: Date) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        return "\(month)月\(day)日 · \(weekdayName(date))"
    }

    func weekdayName(_ date: Date) -> String {
        let index = (calendar.component(.weekday, from: date) + 5) % 7
        let names = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return names[max(0, min(names.count - 1, index))]
    }

    // MARK: - Data

    func planDay(on date: Date, plan: TrainingPlan?) -> PlanDay? {
        plan?.day(on: date)
    }

    func beginCalendarTraining(plan: TrainingPlan?) {
        let plannedDay = planDay(on: selectedDate, plan: plan)
        let isLight = store.periodDay(for: selectedDate)?.mode == .light
        let time = calendar.date(
            bySettingHour: 19,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate

        let completedBySlug: [String: Int] = plannedDay.map { day in
            store.planDaySessions(day).reduce(into: [String: Int]()) { result, session in
                for set in session.sets where set.completed {
                    result[set.slug, default: 0] += 1
                }
            }
        } ?? [:]

        var sets: [SetLog] = []
        var plannedTotal = 0
        for item in plannedDay?.exercises ?? [] {
            let reps = Int(WorkoutPickerOptions.normalizedReps(item.reps)) ?? 10
            let baseWeight = max(0, item.weightKG ?? 0)
            let weight = isLight && baseWeight > 0
                ? ((baseWeight * 0.8) * 2).rounded() / 2
                : baseWeight
            let setCount = max(1, isLight ? max(2, item.sets - 1) : item.sets)
            plannedTotal += setCount
            let done = min(setCount, completedBySlug[item.slug, default: 0])
            let remaining = max(0, setCount - done)
            for index in 0..<remaining {
                sets.append(
                    SetLog(
                        slug: item.slug,
                        setIndex: done + index + 1,
                        weightKG: weight,
                        reps: reps,
                        rpe: item.rpe
                    )
                )
            }
        }

        sessionSheet = SessionSheet(
            session: WorkoutSession(
                date: time,
                dayTitle: plannedDay?.title ?? "训练记录",
                durationMinutes: plannedDay?.estimatedMinutes ?? 45,
                feeling: 3,
                notes: nil,
                sets: sets,
                programDayID: plannedDay?.id.uuidString,
                plannedSets: plannedTotal > 0 ? plannedTotal : nil
            ),
            isNew: true
        )
    }

    func sessions(on date: Date) -> [WorkoutSession] {
        store.sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    func foodLogs(on date: Date) -> [FoodLog] {
        store.foodLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func nutritionTotals(_ logs: [FoodLog]) -> NutritionTotals {
        logs.reduce(into: NutritionTotals()) { total, log in
            total.kcal += log.kcal
            total.protein += log.protein
            total.carbs += log.carbs
            total.fat += log.fat
        }
    }
}
