import Foundation
import XCTest
@testable import FitAI

final class WeatherTests: XCTestCase {
    func testWMOCodesMapToExpectedKinds() {
        XCTAssertEqual(WeatherKind(code: 0), .clear)
        XCTAssertEqual(WeatherKind(code: 3), .overcast)
        XCTAssertEqual(WeatherKind(code: 61), .rain)
        XCTAssertEqual(WeatherKind(code: 65), .heavyRain)
        XCTAssertEqual(WeatherKind(code: 71), .snow)
        XCTAssertEqual(WeatherKind(code: 95), .thunderstorm)
        XCTAssertEqual(WeatherKind(code: 999), .unknown)
    }

    func testAlertKindPrioritizesTyphoonThenThunderThenSnowThenRain() {
        XCTAssertEqual(makeSnapshot(code: 61, windKPH: 90).alertKind, .typhoon)
        XCTAssertEqual(makeSnapshot(code: 61, windKPH: 70).alertKind, .typhoon)
        XCTAssertEqual(makeSnapshot(code: 95).alertKind, .thunder)
        XCTAssertEqual(makeSnapshot(code: 71).alertKind, .snow)
        XCTAssertEqual(makeSnapshot(code: 61).alertKind, .rain)
        XCTAssertEqual(makeSnapshot(code: 0, probability: 60).alertKind, .rainLikely)
        XCTAssertNil(makeSnapshot(code: 0, probability: 59).alertKind)
    }

    func testDayPhaseUsesProvidedTimeZone() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let calendar = makeCalendar(timeZone: utc)
        let dawn = makeDate(calendar: calendar, hour: 6, minute: 30)
        let day = makeDate(calendar: calendar, hour: 12, minute: 0)
        let evening = makeDate(calendar: calendar, hour: 18, minute: 30)
        let night = makeDate(calendar: calendar, hour: 23, minute: 0)

        XCTAssertEqual(WeatherAtmosphere.phase(for: dawn, timeZone: utc), .morning)
        XCTAssertEqual(WeatherAtmosphere.phase(for: day, timeZone: utc), .noon)
        XCTAssertEqual(WeatherAtmosphere.phase(for: evening, timeZone: utc), .evening)
        XCTAssertEqual(WeatherAtmosphere.phase(for: night, timeZone: utc), .night)
    }

    func testAtmosphereUsesWeatherTimeZone() {
        let utc = TimeZone(secondsFromGMT: 0)!
        let calendar = makeCalendar(timeZone: utc)
        let date = makeDate(calendar: calendar, hour: 10, minute: 0)
        var snapshot = makeSnapshot(code: 61)
        snapshot.timezone = "Asia/Shanghai"

        let atmosphere = WeatherAtmosphere.make(snapshot: snapshot, date: date)

        XCTAssertEqual(atmosphere.phase, .evening)
        XCTAssertTrue(atmosphere.isPrecipitation)
        XCTAssertEqual(atmosphere.kind, .rain)
    }

    func testRainProbabilityBecauseCurrentWeatherIsDry() {
        let snapshot = makeSnapshot(code: 0, probability: 80)
        XCTAssertFalse(snapshot.isWet)
        XCTAssertEqual(snapshot.alertKind, .rainLikely)
    }

    func testAtmosphereKeepsWindAndCloudCover() {
        let snapshot = makeSnapshot(code: 61, windKPH: 70)
        let atmosphere = WeatherAtmosphere.make(snapshot: snapshot)

        XCTAssertTrue(atmosphere.isWindy)
        XCTAssertTrue(atmosphere.isTyphoon)
        XCTAssertGreaterThan(atmosphere.windIntensity, 0.6)
        XCTAssertEqual(atmosphere.cloudCover, 50)
    }

    private func makeSnapshot(
        code: Int,
        precipitation: Double = 0,
        probability: Int? = nil,
        windKPH: Double = 8
    ) -> WeatherSnapshot {
        WeatherSnapshot(
            temperatureC: 18,
            apparentTemperatureC: 17,
            humidity: 60,
            windKPH: windKPH,
            weatherCode: code,
            isDay: true,
            precipitationMM: precipitation,
            rainMM: 0,
            showersMM: 0,
            snowfallCM: 0,
            cloudCover: 50,
            highC: 22,
            lowC: 12,
            precipitationProbability: probability,
            timezone: "Asia/Shanghai",
            placeName: "杭州",
            latitude: 30.27,
            longitude: 120.15,
            updatedAt: Date()
        )
    }

    private func makeCalendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func makeDate(calendar: Calendar, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 28
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
