import Foundation
import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth

    @State private var draft = UserProfile()
    @State private var step = 0
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showExitConfirm = false

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ProfileFormView(draft: $draft, step: step)
                if step == 0 {
                    safetyCard
                }

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
                HStack(spacing: 10) {
                    if step > 0 {
                        Button("上一步") {
                            withAnimation(Motion.smooth) {
                                step -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 110)
                    }

                    Button {
                        advance()
                    } label: {
                        Text(step < 4 ? "下一步" : "生成我的计划")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .background(Theme.chrome)
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

    private var stepTitle: String {
        switch step {
        case 0: return "先认识你"
        case 1: return "身体基线"
        case 2: return "你能用什么"
        case 3: return "一周怎么安排"
        default: return "目标定清楚"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: return "基础信息用于计算热量与训练负荷。"
        case 1: return "体重、体脂和围度会用来追踪变化，不用追求完美数字。"
        case 2: return "只选你实际能用的器械，计划才不会落空。"
        case 3: return "按真实出勤频率安排，比一开始练太猛更重要。"
        default: return "目标只作方向，减重建议不超过 0.5kg/周。"
        }
    }

    private func advance() {
        if step == 0 {
            let name = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                alertMessage = "先填一个称呼，方便教练在对话里称呼你。"
                showAlert = true
                return
            }
        }
        guard step < 4 else {
            save()
            return
        }
        withAnimation(Motion.smooth) {
            step += 1
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

            HStack {
                Text("起步评估")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(step + 1) / 5")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.accent : Theme.surfaceStrong)
                        .frame(height: 3)
                }
            }
            .animation(Motion.quick, value: step)

            Text(stepTitle)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(stepSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
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

        guard draft.equipment.contains(where: { equipment in
            ExerciseLibrary.all.contains { $0.equipment == equipment && $0.muscle != .cardio }
        }) else {
            alertMessage = "请至少选择一种可用器械：徒手 / 哑铃 / 杠铃 / 固定器械 / 绳索 / 弹力带 / 壶铃。"
            showAlert = true
            return
        }

        draft.nickname = name
        store.completeOnboarding(draft)
    }
}
