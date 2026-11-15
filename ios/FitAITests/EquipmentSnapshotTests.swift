import XCTest
@testable import FitAI

final class EquipmentSnapshotTests: XCTestCase {
    func testSnapshotKeepsSourcesSeparate() {
        let snapshot = EquipmentSnapshot(
            profileTypes: [.barbell, .dumbbell],
            libraryItems: [EquipmentItem(name: "腿举机")],
            universalItems: [
                UniversalEquipment(slug: "bodyweight", name: "徒手", defaultOn: true)
            ],
            planPoolSlugs: ["squat", "row"]
        )

        XCTAssertEqual(snapshot.profileTypes.map(\.label), ["杠铃", "哑铃"])
        XCTAssertEqual(snapshot.profileTypeSummary, "杠铃 / 哑铃")
        XCTAssertEqual(snapshot.libraryItems.map(\.name), ["腿举机"])
        XCTAssertEqual(snapshot.universalSummary, "徒手")
        XCTAssertEqual(snapshot.planPoolSlugs, ["squat", "row"])
    }

    func testEmptySnapshotUsesReadableFallbacks() {
        let snapshot = EquipmentSnapshot(
            profileTypes: [],
            libraryItems: [],
            universalItems: [],
            planPoolSlugs: []
        )

        XCTAssertEqual(snapshot.profileTypeSummary, "未选择")
        XCTAssertEqual(snapshot.universalSummary, "未勾选")
    }
}
