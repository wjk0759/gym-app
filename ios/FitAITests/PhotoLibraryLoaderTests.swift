import XCTest
import UIKit

@testable import FitAI

final class PhotoLibraryLoaderTests: XCTestCase {
    func testFitWithinCapsLongestSideAndKeepsAspectRatio() {
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 4000, height: 2000)
        ).image { context in
            UIColor.systemTeal.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 4000, height: 2000))
        }

        let fitted = source.fitWithin(maxDimension: 1600)

        XCTAssertLessThanOrEqual(max(fitted.size.width, fitted.size.height), 1600.1)
        XCTAssertEqual(
            fitted.size.width / fitted.size.height,
            2,
            accuracy: 0.01
        )
    }

    func testFitWithinLeavesSmallImageAlone() {
        let source = UIGraphicsImageRenderer(
            size: CGSize(width: 800, height: 600)
        ).image { context in
            UIColor.systemTeal.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }

        let fitted = source.fitWithin(maxDimension: 1600)

        XCTAssertEqual(fitted.size.width, 800, accuracy: 0.5)
        XCTAssertEqual(fitted.size.height, 600, accuracy: 0.5)
    }
}
