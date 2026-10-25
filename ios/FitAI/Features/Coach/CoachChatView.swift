import SwiftUI

struct CoachChatView: View {
    @Environment(AppStore.self) private var store

    @State private var input = ""
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
            .toolbar {
                if !store.chat.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空") { store.clearChat() }
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
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
                        Text("训练有问题，直接问")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("结合档案、计划和训练记录回答")
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

            VStack(alignment: .leading, spacing: 10) {
                Text("快速开始")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(starters) { item in
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
            TextField("问问动作、计划或饮食…", text: $input, axis: .vertical)
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
        store.sendChat(trimmed)
        input = ""
        focused = false
    }
}
