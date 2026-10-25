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

                Text("保存资料不会自动覆盖当前训练计划；如需让计划适配新的目标或器械，可回到「计划」页让 AI 复盘调整。")
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider().overlay(Theme.stroke)
                Button(action: save) {
                    Text("保存资料")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
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

        draft.nickname = name
        draft.equipment.insert(.bodyweight)
        store.updateProfile(draft)
        dismiss()
    }
}
