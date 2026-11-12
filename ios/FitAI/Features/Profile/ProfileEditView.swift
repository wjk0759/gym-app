import Foundation
import SwiftUI

struct ProfileEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = UserProfile()
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showPlanRegenerateConfirm = false

    private var planSettingsChanged: Bool {
        let current = store.profile
        return current.goalType != draft.goalType
            || current.split != draft.split
            || current.weeklyDays != draft.weeklyDays
            || current.sessionMinutes != draft.sessionMinutes
            || current.experience != draft.experience
            || current.equipment != draft.equipment
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ProfileFormView(draft: $draft)

                Text("保存只更新档案；如果训练设置变化，会询问你是否重排计划。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
            .appPagePadding()
            .appPageTopPadding()
        }
        .background(AppBackground())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }
        }
        .keyboardDoneToolbar()
        .onAppear {
            draft = store.profile
        }
        .alert("先确认一下", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "训练设置变化了",
            isPresented: $showPlanRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("仅更新档案") {
                store.updateProfile(draft, regeneratePlan: false)
                dismiss()
            }
            Button("更新并重排计划") {
                store.updateProfile(draft, regeneratePlan: true)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("重排会归档当前计划；正在进行的训练草稿不会被静默清除。")
        }
    }

    private func save() {
        let name = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            alertMessage = "先填一个称呼，方便教练在对话里称呼你。"
            showAlert = true
            return
        }

        if draft.bmi < 18.5 && draft.goalType == .loseFat {
            alertMessage = "当前 BMI 低于 18.5，不建议以减脂为目标。请改为重塑体型或增肌。"
            showAlert = true
            return
        }

        guard draft.equipment.contains(where: { equipment in
            ExerciseLibrary.all.contains { $0.equipment == equipment && $0.muscle != .cardio }
        }) else {
            alertMessage = "请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索 / 弹力带 / 壶铃。"
            showAlert = true
            return
        }

        draft.nickname = name
        if planSettingsChanged, store.plan != nil {
            showPlanRegenerateConfirm = true
            return
        }
        store.updateProfile(draft, regeneratePlan: false)
        dismiss()
    }
}
