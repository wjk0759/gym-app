import SwiftUI

/// 单日训练计划编辑：查看/替换/增删动作。保存时由 AppStore 更新计划和远端。
struct PlanEditorView: View {
    @Environment(AppStore.self) private var store

    let day: PlanDay

    var body: some View {
        CustomWorkoutBuilderView(editing: day) { updated in
            store.updateDay(updated)
        }
    }
}
