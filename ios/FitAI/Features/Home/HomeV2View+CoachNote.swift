import SwiftUI

extension HomeV2View {
    // MARK: - Coach note

    var coachNote: some View {
        HStack(alignment: .top, spacing: 10) {
            CoachMark(size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("教练笔记")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
                Text(coachLine)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    var coachLine: String {
        if store.isGenerating {
            return "我在排这 4 周的计划，先按你的目标、器械和伤病来。"
        }
        guard store.plan != nil else {
            return "先建一份 4 周计划，之后我只提醒你今天该做什么。"
        }
        guard let day = selectedDay else {
            return "今天是恢复日。睡够、吃够蛋白，比多练一场更有用。"
        }
        if store.isPlanDayCompleted(day) {
            return "今天已经练完，剩下的交给恢复。"
        }
        if let draft = store.draft(for: day.id) {
            return "上次练到第 \(draft.completedSets) 组，今天接着来。"
        }
        return "今天把「\(day.title)」练明白，别加戏。"
    }
}
