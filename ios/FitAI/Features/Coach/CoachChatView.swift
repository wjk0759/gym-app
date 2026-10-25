import SwiftUI

struct CoachChatView: View {
    @Environment(AppStore.self) private var store

    @State private var input = ""
    @State private var selectedSkill: CoachSkill = .trainer
    @State private var showPaywall = false
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
                skillPicker

                ScrollViewReader { proxy in
                    ScrollView {
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

                if !store.chat.isEmpty {
                    suggestionBar
                }

                inputBar
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("AI 教练")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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
        HStack(spacing: 10) {
            TextField(selectedSkill.placeholder, text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.isReplying else { return }
        store.sendChat(trimmed, skill: selectedSkill)
        input = ""
        focused = false
    }
}
