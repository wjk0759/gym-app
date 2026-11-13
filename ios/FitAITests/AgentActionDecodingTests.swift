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

    func testLogFoodActionDecodesItems() throws {
        let json = """
        {
          "id": "food-1",
          "type": "log_food",
          "title": "记录午餐",
          "summary": "约 775 kcal",
          "requires_confirmation": true,
          "payload": {
            "date": "2026-11-13",
            "meal": "lunch",
            "items": [
              {
                "name": "湿炒螺蛳粉",
                "portion": "1份",
                "grams": 500,
                "kcal": 600,
                "protein_g": 22,
                "carbs_g": 80,
                "fat_g": 18,
                "confidence": 0.72
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let action = try JSONDecoder().decode(AgentAction.self, from: json)

        XCTAssertEqual(action.type, "log_food")
        XCTAssertEqual(action.payload?.meal, "lunch")
        XCTAssertEqual(action.payload?.items?.count, 1)
        XCTAssertEqual(action.payload?.items?.first?.name, "湿炒螺蛳粉")
        XCTAssertEqual(action.payload?.items?.first?.proteinG, 22)
    }

    func testAgentChatResponseDecodesMessageID() throws {
        let json = """
        {
          "session_id": "00000000-0000-0000-0000-000000000001",
          "message_id": "00000000-0000-0000-0000-000000000002",
          "run_id": "run-1",
          "status": "completed",
          "reply": "今天练腿。",
          "proposal": null,
          "actions": [],
          "safety_flag": null,
          "elapsed_ms": 1200
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(
            AgentChatResponse.self,
            from: json
        )

        XCTAssertEqual(
            response.messageID,
            "00000000-0000-0000-0000-000000000002"
        )
        XCTAssertEqual(response.runID, "run-1")
    }
}
