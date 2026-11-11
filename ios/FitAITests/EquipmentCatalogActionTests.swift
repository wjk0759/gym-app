import XCTest
@testable import FitAI

final class EquipmentCatalogActionTests: XCTestCase {
    func testTBarRowOnlyListsTBarRowAsDirectAction() throws {
        let info = try XCTUnwrap(EquipmentCatalog.type(for: "t_bar_row"))
        XCTAssertEqual(info.planEligibleExercises.map(\.slug), ["vital-t-bar-row"])
        XCTAssertFalse(
            info.similarExercises.contains { $0.slug.contains("upright-row") },
            "直立划船不能出现在 T 杠划船机的同类动作里"
        )
    }

    func testRowMachinesDoNotExposeUprightRowsAsDirect() throws {
        for slug in [
            "t_bar_row",
            "seated_row",
            "seated_row_low",
            "seated_row_high",
            "leverage_row",
        ] {
            let info = try XCTUnwrap(EquipmentCatalog.type(for: slug))
            XCTAssertFalse(
                info.planEligibleExercises.contains {
                    $0.slug.contains("upright-row")
                },
                "\(info.nameZH) 不应直接把直立划船当成可练动作"
            )
        }
    }

    func testExplicitExerciseSlugsResolveAndArePlanEligible() throws {
        for info in EquipmentCatalog.all {
            guard let slugs = info.exerciseSlugs else { continue }
            for slug in slugs {
                let exercise = try XCTUnwrap(
                    ExerciseLibrary.exercise(slug: slug),
                    "\(info.nameZH) 引用了不存在的动作 \(slug)"
                )
                XCTAssertTrue(
                    exercise.planEligible,
                    "\(info.nameZH) 引用了不可进计划的动作 \(slug)"
                )
            }
        }
    }
}
