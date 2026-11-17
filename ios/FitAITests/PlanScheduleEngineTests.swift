import XCTest

@testable import FitAI

final class PlanScheduleEngineTests: XCTestCase {
    private let base = FitnessDate.calendar.date(
        from: DateComponents(year: 2026, month: 11, day: 16)
    )!

    private func date(_ offset: Int) -> Date {
        FitnessDate.addingDays(offset, to: base)
    }

    /// Four weeks, five training days per week, Monday to Friday.
    private func makePlan(offsets: [[Int]]? = nil) -> TrainingPlan {
        let layout = offsets ?? (0..<4).map { week in
            (0..<5).map { day in week * 7 + day }
        }
        var days: [PlanDay] = []
        for (weekIndex, weekOffsets) in layout.enumerated() {
            for (slot, offset) in weekOffsets.enumerated() {
                let value = date(offset)
                days.append(
                    PlanDay(
                        weekIndex: weekIndex + 1,
                        weekday: FitnessDate.weekdayNumber(value),
                        date: value,
                        title: "W\(weekIndex + 1)D\(slot + 1)",
                        focus: [],
                        exercises: []
                    )
                )
            }
        }
        return TrainingPlan(
            title: "测试计划",
            createdAt: base,
            weeks: layout.count,
            weeklyDays: 5,
            days: days
        )
    }

    private func selection(from plan: TrainingPlan) -> [Int: [Date]] {
        var result: [Int: [Date]] = [:]
        for week in 1...plan.weeks {
            result[week] = plan.days
                .filter { $0.weekIndex == week && $0.skippedAt == nil }
                .compactMap(\.date)
                .sorted()
        }
        return result
    }

    private func key(_ date: Date?) -> String? {
        date.map { FitnessDate.key($0) }
    }

    private func activeKeys(_ plan: TrainingPlan, week: Int) -> [String] {
        plan.days
            .filter { $0.weekIndex == week && $0.skippedAt == nil }
            .compactMap { key($0.date) }
            .sorted()
    }

    func testUnchangedSelectionKeepsEveryDate() throws {
        let plan = makePlan()
        let result = PlanScheduleEngine.apply(to: plan, selection: selection(from: plan))
        let updated = try result.get()

        XCTAssertEqual(
            updated.days.compactMap { key($0.date) }.sorted(),
            plan.days.compactMap { key($0.date) }.sorted()
        )
        XCTAssertTrue(updated.days.allSatisfy { $0.skippedAt == nil })
    }

    func testUploadTimestampUsesCreationDateForUntouchedPlan() {
        var plan = makePlan()
        plan.createdAt = date(0)
        plan.updatedAt = date(10)

        XCTAssertEqual(
            PlanScheduleEngine.uploadTimestamp(for: plan.days[0], in: plan),
            date(0)
        )
    }

    func testUploadTimestampUsesDayUpdateWhenPresent() {
        var plan = makePlan()
        let updated = date(3)
        plan.days[0].scheduleUpdatedAt = updated

        XCTAssertEqual(
            PlanScheduleEngine.uploadTimestamp(for: plan.days[0], in: plan),
            updated
        )
    }

    func testSeedDatesUsesPlanWeekdays() {
        var plan = makePlan()
        plan.createdAt = date(0)
        for index in plan.days.indices {
            plan.days[index].date = nil
        }

        let seeded = PlanScheduleEngine.seedDates(in: plan)

        XCTAssertEqual(key(seeded.days[0].date), "2026-11-16")
        XCTAssertEqual(key(seeded.days[5].date), "2026-11-23")
    }

    func testRollingPlanStartsOnCreationDayAndRotatesWeekdays() {
        let wednesday = FitnessDate.calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 18)
        )!
        let plan = TrainingPlan(
            title: "滚动计划",
            createdAt: wednesday,
            weeks: 2,
            weeklyDays: 3,
            days: [
                PlanDay(weekday: 1, title: "周一", focus: [], exercises: []),
                PlanDay(weekday: 3, title: "周三", focus: [], exercises: []),
                PlanDay(weekday: 5, title: "周五", focus: [], exercises: []),
            ]
        )

        XCTAssertEqual(key(plan.date(week: 1, weekday: 3)), "2026-11-18")
        XCTAssertEqual(key(plan.date(week: 1, weekday: 5)), "2026-11-20")
        XCTAssertEqual(key(plan.date(week: 1, weekday: 1)), "2026-11-23")
        XCTAssertEqual(key(plan.date(week: 2, weekday: 3)), "2026-11-25")
    }

    func testSeedDatesAnchorsRollingPlanOnCreationDay() {
        let wednesday = FitnessDate.calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 18)
        )!
        var plan = TrainingPlan(
            title: "滚动计划",
            createdAt: wednesday,
            weeks: 1,
            weeklyDays: 3,
            days: [
                PlanDay(weekday: 1, title: "周一", focus: [], exercises: []),
                PlanDay(weekday: 3, title: "周三", focus: [], exercises: []),
                PlanDay(weekday: 5, title: "周五", focus: [], exercises: []),
            ]
        )
        for index in plan.days.indices {
            plan.days[index].date = nil
        }

        let seeded = PlanScheduleEngine.seedDates(in: plan)

        XCTAssertEqual(
            seeded.days.compactMap { key($0.date) }.sorted(),
            ["2026-11-18", "2026-11-20", "2026-11-23"]
        )
    }

    func testRollingPlanScheduleKeepsSevenDayWindows() throws {
        let wednesday = FitnessDate.calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 18)
        )!
        var plan = TrainingPlan(
            title: "滚动计划",
            createdAt: wednesday,
            weeks: 1,
            weeklyDays: 3,
            days: [
                PlanDay(weekday: 1, title: "周一", focus: [], exercises: []),
                PlanDay(weekday: 3, title: "周三", focus: [], exercises: []),
                PlanDay(weekday: 5, title: "周五", focus: [], exercises: []),
            ]
        )
        for index in plan.days.indices {
            plan.days[index].date = nil
        }
        plan = PlanScheduleEngine.seedDates(in: plan)
        var dates = selection(from: plan)
        dates[1] = [
            "2026-11-18",
            "2026-11-20",
            "2026-11-23",
        ].compactMap { FitnessDate.date(from: $0) }

        let updated = try PlanScheduleEngine.apply(
            to: plan,
            selection: dates
        ).get()

        XCTAssertEqual(
            activeKeys(updated, week: 1),
            ["2026-11-18", "2026-11-20", "2026-11-23"]
        )
        XCTAssertTrue(updated.days.allSatisfy { $0.skippedAt == nil })
    }

    func testDeselectingMiddleDaySkipsThatDayInsteadOfTheLastOne() throws {
        let plan = makePlan()
        let thursday = try XCTUnwrap(
            plan.days.first { key($0.date) == "2026-11-18" }
        )
        var dates = selection(from: plan)
        dates[1]?.removeAll { FitnessDate.key($0) == "2026-11-18" }

        let updated = try PlanScheduleEngine.apply(to: plan, selection: dates).get()

        let changed = try XCTUnwrap(updated.days.first { $0.id == thursday.id })
        XCTAssertNotNil(changed.skippedAt)
        XCTAssertNil(changed.date)
        XCTAssertEqual(activeKeys(updated, week: 1), ["2026-11-16", "2026-11-17", "2026-11-19", "2026-11-20"])
        XCTAssertEqual(activeKeys(updated, week: 2), ["2026-11-23", "2026-11-24", "2026-11-25", "2026-11-26", "2026-11-27"])
    }

    func testReaddingSkippedDateRestoresTheSameDay() throws {
        let plan = makePlan()
        let thursday = try XCTUnwrap(
            plan.days.first { key($0.date) == "2026-11-18" }
        )
        var reduced = selection(from: plan)
        reduced[1]?.removeAll { FitnessDate.key($0) == "2026-11-18" }
        let skipped = try PlanScheduleEngine.apply(to: plan, selection: reduced).get()

        var full = selection(from: skipped)
        full[1] = (full[1] ?? []) + [date(2)]
        full[1]?.sort()
        let restored = try PlanScheduleEngine.apply(to: skipped, selection: full).get()

        let changed = try XCTUnwrap(restored.days.first { $0.id == thursday.id })
        XCTAssertNil(changed.skippedAt)
        XCTAssertEqual(key(changed.date), "2026-11-18")
    }

    func testMovingMiddleDayKeepsOtherDatesInPlace() throws {
        let plan = makePlan()
        let thursday = try XCTUnwrap(
            plan.days.first { key($0.date) == "2026-11-18" }
        )
        var dates = selection(from: plan)
        dates[1]?.removeAll { FitnessDate.key($0) == "2026-11-18" }
        dates[1] = (dates[1] ?? []) + [date(5)]
        dates[1]?.sort()

        let updated = try PlanScheduleEngine.apply(to: plan, selection: dates).get()

        let moved = try XCTUnwrap(updated.days.first { $0.id == thursday.id })
        XCTAssertEqual(key(moved.date), "2026-11-21")
        XCTAssertNil(moved.skippedAt)
        XCTAssertEqual(activeKeys(updated, week: 1), ["2026-11-16", "2026-11-17", "2026-11-19", "2026-11-20", "2026-11-21"])
    }

    func testDuplicateCurrentDateStaysOnTheActiveDay() throws {
        let plan = makePlan(offsets: [
            [0, 1, 2, 2, 4],
            [7, 8, 9, 10, 11],
            [14, 15, 16, 17, 18],
            [21, 22, 23, 24, 25],
        ])
        let duplicateIDs = Set(
            plan.days.filter { key($0.date) == "2026-11-18" }.map(\.id)
        )

        var dates = selection(from: plan)
        dates[1] = ["2026-11-16", "2026-11-17", "2026-11-18", "2026-11-20"]
            .compactMap { FitnessDate.date(from: $0) }

        let updated = try PlanScheduleEngine.apply(to: plan, selection: dates).get()

        let changed = updated.days.filter { duplicateIDs.contains($0.id) }
        XCTAssertEqual(changed.count, 2)
        XCTAssertEqual(changed.filter { $0.skippedAt == nil }.count, 1)
        XCTAssertEqual(changed.filter { $0.skippedAt == nil && key($0.date) == "2026-11-18" }.count, 1)
        XCTAssertEqual(changed.filter { $0.date == nil }.count, 1)
        XCTAssertEqual(activeKeys(updated, week: 1), ["2026-11-16", "2026-11-17", "2026-11-18", "2026-11-20"])
    }

    func testTooManyDaysReturnsWeeklyLimitError() {
        let plan = makePlan()
        var dates = selection(from: plan)
        dates[1] = (0..<6).map { date($0) }

        let result = PlanScheduleEngine.apply(to: plan, selection: dates)

        XCTAssertEqual(result.failure, PlanScheduleValidationError.tooManyDays(week: 1, limit: 5))
        XCTAssertEqual(result.failure?.message, "第 1 周最多选 5 天")
    }

    func testFewerSlotsReturnsSpecificError() {
        let plan = makePlan(offsets: [
            [0, 1],
            [7, 8],
            [14, 15],
            [21, 22],
        ])
        var dates = selection(from: plan)
        dates[1] = [date(0), date(1), date(2)]

        let result = PlanScheduleEngine.apply(to: plan, selection: dates)

        XCTAssertEqual(result.failure, PlanScheduleValidationError.notEnoughSlots(week: 1, slots: 2))
        XCTAssertEqual(result.failure?.message, "第 1 周只有 2 个训练位")
    }

    func testMissingWeekReturnsSpecificError() {
        let plan = makePlan()
        var dates = selection(from: plan)
        dates[3] = nil

        let result = PlanScheduleEngine.apply(to: plan, selection: dates)

        XCTAssertEqual(result.failure, PlanScheduleValidationError.missingWeek(3))
        XCTAssertEqual(result.failure?.message, "第 3 周日期不完整")
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
