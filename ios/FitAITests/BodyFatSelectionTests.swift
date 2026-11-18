import XCTest
@testable import FitAI

final class BodyFatSelectionTests: XCTestCase {
    func testMaleBodyFatBandsKeepStableReportPercentages() throws {
        let options = BodyFatOption.options(for: .male)
        let low = try XCTUnwrap(options.first { $0.id == "male_16_20" })
        let high = try XCTUnwrap(options.first { $0.id == "male_25_29" })

        XCTAssertEqual(low.label, "16–20%")
        XCTAssertEqual(low.midpoint, 18)
        XCTAssertEqual(high.label, "25–29%")
        XCTAssertEqual(high.midpoint, 27)
    }

    func testBodyFatOptionsHaveUniqueIDs() {
        for sex in [Sex.male, Sex.female] {
            let options = BodyFatOption.options(for: sex)
            XCTAssertEqual(Set(options.map(\.id)).count, options.count)
        }
    }
}
