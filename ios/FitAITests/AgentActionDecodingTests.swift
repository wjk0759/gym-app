import XCTest

@testable import FitAI

final class AgentActionDecodingTests: XCTestCase {
    func testModifyWorkoutPayloadDecodes() throws {
        let json = """
        {
          "id": "a1",
          "type": "modify_workout",
          "title": "改课",
          "summary": "卧推换成哑铃卧推",
          "requires_confirmation": true,
          "payload": {
            "day_id": "day-1",
            "scope": "day",
            "changes": [
              {"op": "swap", "from_slug": "bench_press", "to_slug": "dumbbell_press"},
              {"op": "sets", "slug": "dumbbell_press", "sets": 2},
              {"op": "weight", "slug": "dumbbell_press", "weight_kg": 17.5}
            ]
          }
        }
        """.data(using: .utf8)!

        let action = try JSONDecoder().decode(AgentAction.self, from: json)

        XCTAssertEqual(action.type, "modify_workout")
        XCTAssertEqual(action.payload?.dayID, "day-1")
        XCTAssertEqual(action.payload?.scope, "day")
        XCTAssertEqual(action.payload?.changes?.count, 3)
        XCTAssertEqual(action.payload?.changes?.first?.op, "swap")
        XCTAssertEqual(action.payload?.changes?.first?.toSlug, "dumbbell_press")
        XCTAssertEqual(action.payload?.changes?.last?.weightKG, 17.5)
    }
}
