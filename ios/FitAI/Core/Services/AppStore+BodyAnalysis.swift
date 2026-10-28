import Foundation

extension AppStore {
    // MARK: - Body analysis

    func addBodyAnalysis(_ analysis: BodyAnalysis) {
        bodyAnalyses.insert(analysis, at: 0)
        persist()
    }

    func applyBodyAnalysis(_ analysis: BodyAnalysis) {
        guard var current = plan else {
            toast = "先生成训练计划，再应用体型分析"
            return
        }

        current.version += 1
        current.updatedAt = Date()
        current.days = current.days.map { day in
            var newDay = day
            newDay.id = UUID()
            newDay.exercises = day.exercises.map { item in
                var newItem = item
                newItem.id = UUID()
                if let muscle = item.exercise?.muscle,
                   analysis.focusAreas.contains(muscle) {
                    newItem.sets = min(6, item.sets + 1)
                }
                return newItem
            }
            return newDay
        }
        archiveCurrentPlan()
        plan = current

        if let index = bodyAnalyses.firstIndex(where: { $0.id == analysis.id }) {
            bodyAnalyses[index].appliedToPlan = true
        } else {
            var copy = analysis
            copy.appliedToPlan = true
            bodyAnalyses.insert(copy, at: 0)
        }

        toast = "已应用体型分析：重点部位每周增加 1 组"
        persist()
    }

    /// 体型分析后跳转到 AI 教练：把分析结果作为上下文带进对话，闭环继续。
    func openCoachAfterBodyAnalysis(_ analysis: BodyAnalysis) {
        let focus = analysis.focusAreas.map(\.label).joined(separator: "、")
        var text = "📋 体型分析结果\n\n\(analysis.summary)\n\n训练重点：\(focus.isEmpty ? "全身均衡" : focus)"
        if !analysis.recommendations.isEmpty {
            text += "\n\n建议：\n" + analysis.recommendations.map { "· \($0)" }.joined(separator: "\n")
        }
        text += "\n\n你可以让我根据这个分析调整训练计划，或者告诉我你的想法。"
        chat.append(ChatMessage(role: .assistant, text: text))
        coachContext = text
        persist()
        selectedTab = 2
    }
}
