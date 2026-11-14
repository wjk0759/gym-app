import XCTest

@testable import FitAI

final class WeekStripWindowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        ))!
    }

    func testWindowIsThreeBeforeTodayAndThreeAfter() {
        let today = day(2026, 11, 15)
        let dates = WeekStripWindow.dates(around: today, calendar: calendar)

        XCTAssertEqual(dates.count, 7)
        XCTAssertTrue(calendar.isDate(dates[3], inSameDayAs: today))
        XCTAssertTrue(calendar.isDate(dates[0], inSameDayAs: day(2026, 11, 12)))
        XCTAssertTrue(calendar.isDate(dates[6], inSameDayAs: day(2026, 11, 18)))
    }

    func testWindowCrossesMonthAndYearBoundaries() {
        let dates = WeekStripWindow.dates(around: day(2026, 12, 31), calendar: calendar)

        XCTAssertTrue(calendar.isDate(dates[0], inSameDayAs: day(2026, 12, 28)))
        XCTAssertTrue(calendar.isDate(dates[3], inSameDayAs: day(2026, 12, 31)))
        XCTAssertTrue(calendar.isDate(dates[6], inSameDayAs: day(2027, 1, 3)))
    }

    func testWindowHandlesDaylightSavingTransition() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.locale = Locale(identifier: "en_US_POSIX")
        newYork.timeZone = TimeZone(identifier: "America/New_York")!

        let dates = WeekStripWindow.dates(
            around: newYork.date(from: DateComponents(
                year: 2026,
                month: 3,
                day: 8,
                hour: 12
            ))!,
            calendar: newYork
        )

        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(Set(dates.map { newYork.startOfDay(for: $0) }).count, 7)
        XCTAssertEqual(newYork.component(.day, from: dates[3]), 8)
        XCTAssertEqual(newYork.component(.month, from: dates[3]), 3)
    }
}
