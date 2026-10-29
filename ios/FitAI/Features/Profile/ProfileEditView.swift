import Foundation
import SwiftUI

struct ProfileEditView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = UserProfile()
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ProfileFormView(draft: $draft)

                Text("修改目标、训练安排、时长或器械后，保存会自动按新设置重排计划；手动改过的训练日会被覆盖。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(AppBackground())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
            }
        }
        .onAppear {
            draft = store.profile
        }
        .alert("先确认一下", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
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
        store.updateProfile(draft)
        dismiss()
    }
}
