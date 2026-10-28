import Foundation
import XCTest
@testable import FitAI

final class CoachVisualMemoryTests: XCTestCase {
    func testMemoryKeepsVisibleFactsAndSessionForFollowUp() {
        let sessionID = UUID()
        let result = CoachVisionResult(
            mode: "body",
            isTraining: false,
            summary: "能看到人物上半身，体脂只能做粗略视觉估算。",
            observations: ["坐着抱猫", "只有上半身入镜"],
            nextCue: nil,
            safetyFlag: nil,
            warning: nil,
            sessionID: sessionID
        )

        let memory = CoachVisualMemory(
            result: result,
            imageCount: 1,
            question: "图中人物体脂率多少？"
        )

        XCTAssertEqual(memory.sessionID, sessionID)
        XCTAssertEqual(memory.imageCount, 1)
        XCTAssertTrue(memory.promptText.contains("上半身"))
        XCTAssertTrue(memory.promptText.contains("图中人物体脂率多少"))
    }

    func testMemoryClampsImageCountToAtLeastOne() {
        let result = CoachVisionResult(
            mode: "general",
            isTraining: false,
            summary: "图片已分析。",
            observations: [],
            nextCue: nil,
            safetyFlag: nil,
            warning: nil,
            sessionID: nil
        )

        let memory = CoachVisualMemory(result: result, imageCount: 0, question: "")

        XCTAssertEqual(memory.imageCount, 1)
        XCTAssertFalse(memory.promptText.contains("当时问题"))
    }
}
