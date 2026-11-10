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

    func testVisibleCategoryTreeHidesEmptyAndCatchAllBranches() {
        let tree = ExerciseLibrary.visibleCategoryTree
        let l1 = tree.map(\.l1)

        XCTAssertEqual(tree.count, 8)
        XCTAssertFalse(l1.contains("other"))
        XCTAssertEqual(
            ExerciseLibrary.subcategories(for: "胸"),
            ["胸大肌", "下胸"]
        )
        XCTAssertEqual(
            Set(ExerciseLibrary.subcategories(for: "背")),
            ["背阔肌", "上背", "斜方肌", "菱形肌"]
        )
        XCTAssertEqual(
            Set(ExerciseLibrary.subcategories(for: "核心")),
            ["腹直肌", "下背", "侧腹"]
        )
        XCTAssertTrue(ExerciseLibrary.subcategories(for: "全身").isEmpty)
    }

    func testAliasSearchFindsCommonNames() {
        let cases: [(query: String, slug: String)] = [
            ("双杠抬腿", "vital-captain-s-chair-leg-raise"),
            ("臀冲", "vital-hip-thrust"),
            ("B站姿", "vital-b-stance-squat-hack-squat-machine"),
            ("EZ杆", "vital-ez-bar-curl"),
            ("bench press", "vital-dumbbell-bench-press"),
        ]

        for item in cases {
            let matches = ExerciseLibrary.search(item.query).map(\.slug)
            XCTAssertTrue(
                matches.contains(item.slug),
                "\(item.query) should match \(item.slug), got \(matches.prefix(8))"
            )
        }
    }

    func testPlanPoolIsStrengthOnly() {
        let excludedCategories: Set<String> = [
            "拉伸", "有氧", "热身动作", "other",
        ]

        XCTAssertFalse(ExerciseLibrary.planEligible.isEmpty)
        for exercise in ExerciseLibrary.planEligible {
            XCTAssertFalse(
                excludedCategories.contains(exercise.categoryL1 ?? ""),
                "\(exercise.nameZH) should not be in the default plan pool"
            )
        }
    }

    func testUniversalEquipmentDefaultsAndPools() {
        let defaults = Dictionary(
            uniqueKeysWithValues: ExerciseLibrary.universalEquipment.map {
                ($0.slug, $0.defaultOn)
            }
        )
        XCTAssertEqual(defaults["bodyweight"], true)
        XCTAssertEqual(defaults["dumbbell"], false)
        XCTAssertFalse(
            ExerciseLibrary.universalExercises["bodyweight", default: []].isEmpty
        )
    }
}
