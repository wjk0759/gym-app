import Foundation
import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth

    @State private var draft = UserProfile()
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showExitConfirm = false

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ProfileFormView(draft: $draft)
                safetyCard

                Text("继续即表示你已阅读并同意《用户协议》与《隐私政策》。健康数据仅用于生成训练与饮食建议。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .background(AppBackground())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider().overlay(Theme.stroke)
                Button(action: save) {
                    Text("生成我的计划")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if !store.profile.nickname.isEmpty {
                draft = store.profile
            }
        }
        .alert("先确认一下", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "退出登录？",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("继续填写", role: .cancel) {}
        } message: {
            Text("当前填写的内容还没有保存，退出后需要重新填写。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("AI 健身教练")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.accent.opacity(0.12), in: Capsule())

                Spacer()

                Button {
                    showExitConfirm = true
                } label: {
                    Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("退出登录")
            }

            Text("先花 2 分钟\n让计划适合你")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("我们会根据你的目标、器械和可用时间编排训练，并随着记录持续调整。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.bottom, 4)
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case")
                .foregroundStyle(Theme.accent)
            Text("本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .card(padding: 14)
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
        store.completeOnboarding(draft)
    }
}
