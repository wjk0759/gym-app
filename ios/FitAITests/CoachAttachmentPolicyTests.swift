import Foundation
import XCTest
@testable import FitAI

final class CoachAttachmentPolicyTests: XCTestCase {
    func testRemainingSlotsNeverGoNegative() {
        XCTAssertEqual(CoachAttachmentPolicy.remainingImageSlots(currentCount: 0), 6)
        XCTAssertEqual(CoachAttachmentPolicy.remainingImageSlots(currentCount: 4), 2)
        XCTAssertEqual(CoachAttachmentPolicy.remainingImageSlots(currentCount: 9), 0)
    }

    func testAcceptsImageWithinAllLimits() {
        let existing = [Data(count: 1_000)]
        let incoming = Data(count: 2_000)

        XCTAssertNil(CoachAttachmentPolicy.validationError(appending: incoming, to: existing))
    }

    func testRejectsTooManyImages() {
        let existing = Array(repeating: Data(count: 10), count: 6)
        let error = CoachAttachmentPolicy.validationError(
            appending: Data(count: 10),
            to: existing
        )

        XCTAssertEqual(error, "最多只能添加 6 张照片。")
    }

    func testRejectsOversizedImage() {
        let error = CoachAttachmentPolicy.validationError(
            appending: Data(count: CoachAttachmentPolicy.maxImageBytes + 1),
            to: []
        )

        XCTAssertEqual(error, "单张图片不能超过 8MB。")
    }

    func testRejectsTotalOverflow() {
        let existing = Array(repeating: Data(count: 8 * 1024 * 1024), count: 3)
        let error = CoachAttachmentPolicy.validationError(
            appending: Data(count: 1),
            to: existing
        )

        XCTAssertEqual(error, "图片总大小不能超过 24MB。")
    }
}
