import Foundation
import SwiftUI
import UIKit

struct CoachChatView: View {
    @Environment(AppStore.self) private var store

    @State private var input = ""
    @State private var selectedSkill: CoachSkill = .trainer
    @State private var showPaywall = false
    @State private var showCamera = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "今天练什么？",
        "没有器械怎么替代？",
        "深蹲时膝盖不舒服",
        "训练后很酸正常吗？",
        "每天要吃多少蛋白质？"
    ]

    private struct StarterPrompt: Identifiable {
        let text: String
        let icon: String
        var id: String { text }
    }

    private let starters = [
        StarterPrompt(text: "今天练什么？", icon: "calendar"),
        StarterPrompt(text: "没有器械怎么替代？", icon: "dumbbell"),
        StarterPrompt(text: "深蹲膝盖不舒服", icon: "cross.case"),
        StarterPrompt(text: "训练后很酸正常吗？", icon: "bed.double")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if store.planAdjustmentStage > 0 {
                    adjustmentBanner
                } else {
                    skillPicker
                }

                ScrollViewReader { proxy in
                    AppScrollView {
                        if store.chat.isEmpty {
                            welcome
                                .padding(20)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(store.chat) { message in
                                    bubble(message)
                                        .id(message.id)
                                }

                                if store.isReplying {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                            .tint(Theme.accent)
                                        Text("教练正在输入…")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            .padding(20)
                        }
                    }
                    .onChange(of: store.chat.count) { _, _ in
                        guard let last = store.chat.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: store.isReplying) { _, _ in
                        guard let last = store.chat.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                if store.planAdjustmentStage > 0 {
                    if store.planAdjustmentStage == 3, let proposal = store.planAdjustmentProposal {
                        proposalCard(proposal)
                    } else {
                        adjustmentQuickBar
                    }
                } else if !store.chat.isEmpty {
                    suggestionBar
                }

                inputBar
            }
            .background(AppBackground())
            .navigationTitle(store.planAdjustmentStage > 0 ? "调整计划" : "AI 教练")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.planAdjustmentRequested) { _, requested in
                if requested {
                    store.beginPlanAdjustment()
                }
            }
            .onAppear {
                if store.planAdjustmentRequested {
                    store.beginPlanAdjustment()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    title: "拍照问教练",
                    hint: "尽量拍到完整动作或器械，避免脸和隐私部位。照片只用于本次对话。",
                    onImage: { image in
                        store.sendCoachPhoto(image)
                        showCamera = false
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            .toolbar {
                if !store.chat.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空") { store.clearChat() }
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
        }
    }

    private var adjustmentBanner: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("计划调整 · \(String(format: "%02d", store.planAdjustmentStage))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button("结束调整") {
                    store.cancelPlanAdjustment()
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            }
            Text(
                store.planAdjustmentStage == 1
                    ? "说明问题"
                    : store.planAdjustmentStage == 2
                        ? "补充细节"
                        : "确认方案"
            )
            .font(.headline)
            .foregroundStyle(.white)
            HStack(spacing: 6) {
                ForEach(["说明问题", "补充细节", "确认方案"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(
                            label == (
                                store.planAdjustmentStage == 1
                                    ? "说明问题"
                                    : store.planAdjustmentStage == 2
                                        ? "补充细节"
                                        : "确认方案"
                            ) ? Theme.accent : Theme.tertiaryText
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            Theme.accent.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.accent.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Theme.background)
    }

    private var adjustmentQuickBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.planAdjustmentQuickReplies, id: \.self) { text in
                    Button {
                        store.sendPlanAdjustmentMessage(text)
                    } label: {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func proposalCard(_ proposal: PlanAdjustmentProposal) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("调整方案 · 根据你的反馈")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(proposal.headline)
                .font(.headline)
                .foregroundStyle(.white)
            Text(proposal.summary)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(proposal.changes.prefix(4).enumerated()), id: \.offset) { index, change in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22, alignment: .leading)
                    Text(change)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Button("应用调整") {
                    store.applyPlanAdjustment()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("再改一点") {
                    store.revisePlanAdjustment()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var inputPlaceholder: String {
        if store.planAdjustmentStage == 1 {
            return "说说最近训练最困扰你的地方…"
        }
        if store.planAdjustmentStage == 2 {
            return "补充具体情况，越具体越好…"
        }
        if store.planAdjustmentStage == 3 {
            return "需要再改可以继续说…"
        }
        return selectedSkill.placeholder
    }

    private var skillPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CoachSkill.allCases) { skill in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            selectedSkill = skill
                        }
                    } label: {
                        Label(skill.label, systemImage: skill.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selectedSkill == skill ? Theme.accent : Theme.secondaryText
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedSkill == skill
                                    ? Theme.accent.opacity(0.12)
                                    : Theme.surfaceStrong,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedSkill == skill
                                            ? Theme.accent.opacity(0.5)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.background)
    }

    private var currentStarters: [StarterPrompt] {
        switch selectedSkill {
        case .trainer:
            return starters
        case .rehab:
            return [
                StarterPrompt(text: "膝盖不舒服还能练吗？", icon: "cross.case"),
                StarterPrompt(text: "训练后腰痛怎么恢复？", icon: "figure.walk"),
                StarterPrompt(text: "扭伤后多久能训练？", icon: "clock"),
                StarterPrompt(text: "恢复期能做什么动作？", icon: "figure.cooldown")
            ]
        case .nutrition:
            return [
                StarterPrompt(text: "每天吃多少蛋白质？", icon: "leaf"),
                StarterPrompt(text: "减脂怎么安排三餐？", icon: "fork.knife"),
                StarterPrompt(text: "训练后吃什么？", icon: "takeoutbag.and.cup.and.straw"),
                StarterPrompt(text: "外卖怎么选更健康？", icon: "cart")
            ]
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.13))
                            .frame(width: 42, height: 42)
                        Image(systemName: "brain.head.profile")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedSkill.label)在线")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(selectedSkill.detail)
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }

                Text("涉及疼痛、孕期、术后等情况，我会建议你就医，而不是继续加练。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            if !store.isPro {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("解锁 DeepSeek AI \(selectedSkill.label)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("当前使用本地规则建议；Pro 会员可使用完整 AI Skill。")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("快速开始")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(currentStarters) { item in
                        Button {
                            send(item.text)
                        } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Image(systemName: item.icon)
                                    .font(.headline)
                                    .foregroundStyle(Theme.accent)
                                Text(item.text)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .padding(12)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            weeklyRecap
        }
    }

    private var weeklyRecap: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("本周状态")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("第 \(store.currentPlanWeek) 周")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("\(store.currentWeekSessions.count)/\(store.profile.weeklyDays) 练 · 完成率 \(Int(store.weeklyCompletion * 100))%")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            Button {
                send("帮我复盘一下本周训练，接下来应该怎么调整？")
            } label: {
                Label("让教练复盘本周", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                if message.isSafety {
                    Label("需要就医评估", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }

                if let data = message.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 240)
                        .frame(height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? Color.black : Color.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        message.role == .user
                            ? Theme.accent
                            : (message.isSafety ? Theme.warning.opacity(0.12) : Theme.surface)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        message.isSafety ? Theme.warning.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )

            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }

    private var suggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        send(text)
                    } label: {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.surfaceStrong, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                showCamera = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 42)
                    .background(Theme.surfaceStrong, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("拍照问教练")

            TextField(inputPlaceholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .onChange(of: input) { _, value in
                    if value.count > 500 {
                        input = String(value.prefix(500))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isReplying
                                ? Theme.secondaryText.opacity(0.4)
                                : Theme.accent
                        )
                    )
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isReplying)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Theme.background)
    }

    private func send(_ text: String) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !trimmed.isEmpty, !store.isReplying else { return }
        if store.planAdjustmentStage > 0 {
            store.sendPlanAdjustmentMessage(trimmed)
        } else {
            store.sendChat(trimmed, skill: selectedSkill)
        }
        input = ""
        focused = false
    }
}
