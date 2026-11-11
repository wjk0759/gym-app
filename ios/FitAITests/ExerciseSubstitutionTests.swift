import XCTest
@testable import FitAI

final class ExerciseSubstitutionTests: XCTestCase {
    private func makeProfile(
        equipment: Set<Equipment>,
        injuries: String = "",
        stage: Experience = .beginner
    ) -> UserProfile {
        var profile = UserProfile()
        profile.equipment = equipment
        profile.injuries = injuries
        profile.trainingStage = stage
        return profile
    }

    private func item(_ type: String, name: String = "") -> EquipmentItem {
        EquipmentItem(name: name.isEmpty ? type : name, equipmentType: type)
    }

    private func exercise(_ slug: String) throws -> Exercise {
        try XCTUnwrap(ExerciseLibrary.exercise(slug: slug))
    }

    func testStrictChestPressFallsBackToBodyweightWhenNoEquipmentMatches() throws {
        let current = try exercise("vital-seated-machine-chest-press")
        let result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [item("chest_press_seated", name: "坐姿推胸机")],
            universalSlugs: ["bodyweight"],
            profile: makeProfile(equipment: [.bodyweight, .machine]),
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )

        XCTAssertEqual(result.source, .bodyweight)
        XCTAssertFalse(result.items.isEmpty)
        XCTAssertTrue(result.items.allSatisfy { $0.isBodyweightFallback })
        XCTAssertTrue(
            result.items.contains {
                [
                    "vital-incline-push-up",
                    "vital-standard-push-up",
                    "vital-close-grip-push-ups"
                ].contains($0.exercise.slug)
            }
        )
    }

    func testChestPressUsesDumbbellOnlyWhenBenchIsInPersonalLibrary() throws {
        let current = try exercise("vital-seated-machine-chest-press")
        let profile = makeProfile(equipment: [.bodyweight, .machine, .dumbbell])

        let withoutBench = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [item("chest_press_seated")],
            universalSlugs: ["bodyweight", "dumbbell"],
            profile: profile,
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )
        XCTAssertFalse(
            withoutBench.items.contains { $0.exercise.slug == "vital-dumbbell-bench-press" },
            "没有卧推凳时，不应该建议哑铃卧推"
        )

        let withBench = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [
                item("chest_press_seated"),
                item("bench_press", name: "卧推架")
            ],
            universalSlugs: ["bodyweight", "dumbbell"],
            profile: profile,
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )
        XCTAssertTrue(
            withBench.items.contains { $0.exercise.slug == "vital-dumbbell-bench-press" },
            "有卧推凳和哑铃时，应该建议哑铃卧推"
        )
    }

    func testTBarRowNeverSuggestsUprightRow() throws {
        let current = try exercise("vital-t-bar-row")
        let result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [
                item("t_bar_row", name: "T 杠划船机"),
                item("seated_row", name: "坐姿划船机")
            ],
            universalSlugs: ["bodyweight", "barbell"],
            profile: makeProfile(equipment: [.bodyweight, .barbell, .machine]),
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )

        XCTAssertEqual(result.source, .personal)
        XCTAssertFalse(
            result.items.contains { $0.exercise.slug.contains("upright-row") },
            "T 杠划船不能把直立划船当成替代"
        )
    }

    func testNonStrictModeAddsOutsideLibraryCandidates() throws {
        let current = try exercise("vital-seated-machine-chest-press")
        let result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [],
            universalSlugs: [],
            profile: makeProfile(
                equipment: [.bodyweight, .machine, .dumbbell, .barbell, .cable]
            ),
            strictEquipment: false,
            todaySlugs: [],
            lastSet: { _ in nil }
        )

        XCTAssertEqual(result.source, .personal)
        XCTAssertTrue(result.items.contains { $0.isOutsideLibrary })
        XCTAssertTrue(result.items.contains { $0.exercise.equipment != .bodyweight })
    }

    func testBicepsMachineDoesNotFallBackToTricepsPushUp() throws {
        let current = try exercise("vital-preacher-curl-machine")
        let result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [item("preacher_curl", name: "牧师凳弯举机")],
            universalSlugs: ["bodyweight"],
            profile: makeProfile(equipment: [.bodyweight, .machine]),
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )

        XCTAssertEqual(result.source, .empty)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testBodyweightFallbackHasNoWeightedOrJumpVariants() throws {
        let current = try exercise("vital-seated-machine-chest-press")
        let result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: [item("chest_press_seated")],
            universalSlugs: ["bodyweight"],
            profile: makeProfile(equipment: [.bodyweight, .machine]),
            strictEquipment: true,
            todaySlugs: [],
            lastSet: { _ in nil }
        )

        let banned = ["负重", "跳", "波比", "手枪", "倒立", "单臂", "单手", "击掌", "爆发"]
        for item in result.items {
            XCTAssertFalse(
                banned.contains { item.exercise.nameZH.contains($0) },
                "\(item.exercise.nameZH) 不应该出现在自重兜底里"
            )
        }
    }
}
