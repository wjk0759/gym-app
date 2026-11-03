import XCTest
@testable import FitAI

final class ExerciseLibraryTests: XCTestCase {
    func testBundledLibraryLoadsAndSlugsAreUnique() {
        XCTAssertFalse(ExerciseLibrary.all.isEmpty)
        XCTAssertEqual(
            Set(ExerciseLibrary.all.map(\.slug)).count,
            ExerciseLibrary.all.count
        )
        for exercise in ExerciseLibrary.all {
            XCTAssertNotNil(ExerciseLibrary.exercise(slug: exercise.slug))
        }
    }
}
