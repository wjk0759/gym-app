import Foundation

/// Text-only memory of the latest image/video analysis.
///
/// Raw images stay in local chat history; the backend receives only the
/// compact summary. Keeping this separate from `coachContext` lets a visual
/// follow-up coexist with a body-analysis context instead of overwriting it.
struct CoachVisualMemory: Codable, Equatable {
    var summary: String
    var observations: [String]
    var mode: String
    var imageCount: Int
    var lastQuestion: String
    var updatedAt: Date
    var sessionID: UUID?

    init(result: CoachVisionResult, imageCount: Int, question: String) {
        self.summary = result.summary
        self.observations = Array(result.observations.prefix(3))
        self.mode = result.mode ?? (result.isTraining ? "training" : "general")
        self.imageCount = max(1, imageCount)
        self.lastQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date()
        self.sessionID = result.sessionID
    }

    var promptText: String {
        var parts = [
            "最近一次图片/视频分析（\(imageCount) 张，模式 \(mode)）：",
            summary
        ]
        if !observations.isEmpty {
            parts.append("可见：" + observations.joined(separator: "；"))
        }
        if !lastQuestion.isEmpty {
            parts.append("当时问题：\(lastQuestion)")
        }
        return parts.joined(separator: "\n")
    }
}
