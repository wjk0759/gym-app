import SwiftUI

/// Read-only coach on the wrist. Text is always visible; speech is opt-in.
/// The watch never creates or changes a plan here.
struct WatchVoiceView: View {
    let context: String?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var speech = WatchSpeechService.shared
    @AppStorage("fitai_watch_speech_mode")
    private var speechModeRaw = WatchSpeechMode.silent.rawValue

    @State private var question = ""
    @State private var lastQuestion = ""
    @State private var reply: WatchVoiceReply?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSettings = false

    private var speechMode: WatchSpeechMode {
        WatchSpeechMode(rawValue: speechModeRaw) ?? .silent
    }

    var body: some View {
        ZStack {
            WatchTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    contextRow
                    if let context, !context.isEmpty {
                        Text(context)
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    TextFieldLink(
                        "问教练…",
                        prompt: Text("听写或手写")
                    ) { text in
                        question = text
                        send(text)
                    }
                    .font(.caption)
                    .disabled(isLoading)

                    sendButton

                    if !lastQuestion.isEmpty {
                        questionCard
                    }

                    if isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .tint(WatchTheme.primary)
                            Text("教练正在看你的训练")
                                .font(.caption2)
                                .foregroundStyle(WatchTheme.secondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(WatchTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let reply {
                        answer(reply)
                    }

                    Text("只读回答 · 改计划去 iPhone")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("语音教练")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .accessibilityLabel("朗读设置")
            }
        }
        .sheet(isPresented: $showSettings) {
            speechSettings
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var contextRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WatchTheme.primary)
            Text("叫练 · 训练中")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchTheme.ink)
        }
    }

    private var sendButton: some View {
        Button {
            send()
        } label: {
            Label(
                isLoading ? "思考中…" : "发送",
                systemImage: isLoading ? "ellipsis" : "paperplane.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(WatchPrimaryButtonStyle())
        .disabled(
            isLoading
                || question.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
        )
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("你问")
                .font(.caption2)
                .foregroundStyle(WatchTheme.secondary)
            Text(lastQuestion)
                .font(.caption)
                .foregroundStyle(WatchTheme.ink)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WatchTheme.surface,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func answer(_ reply: WatchVoiceReply) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if reply.requiresPhoneConfirmation {
                Label("需要 iPhone 确认", systemImage: "iphone")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchTheme.warning)
            }
            if reply.safetyFlag != nil {
                Label(
                    "先看安全提示",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchTheme.warning)
            }
            Text(reply.reply)
                .font(.body)
                .foregroundStyle(WatchTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    if speech.isSpeaking {
                        speech.stop()
                    } else {
                        speech.speak(reply.speechText)
                    }
                } label: {
                    Label(
                        speech.isSpeaking ? "停止" : "朗读",
                        systemImage: speech.isSpeaking
                            ? "stop.fill"
                            : "speaker.wave.2.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(WatchTheme.primary)
                .font(.caption2)
                Spacer()
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WatchTheme.surface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(WatchTheme.primary)
                .frame(width: 3)
                .padding(.vertical, 9)
                .padding(.leading, 1)
        }
    }

    private var speechSettings: some View {
        ZStack {
            WatchTheme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("朗读方式")
                        .font(.headline)
                        .foregroundStyle(WatchTheme.ink)
                    ForEach(WatchSpeechMode.allCases) { mode in
                        Button {
                            speechModeRaw = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                    .font(.caption)
                                    .foregroundStyle(WatchTheme.ink)
                                Spacer()
                                if speechMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(WatchTheme.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 3)
                    }
                    Text("默认静音。点“朗读”始终可用；耳机模式只在连接耳机时自动读。")
                        .font(.caption2)
                        .foregroundStyle(WatchTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("完成") {
                        showSettings = false
                    }
                    .buttonStyle(WatchPrimaryButtonStyle())
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func send(_ override: String? = nil) {
        let text = (override ?? question)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        lastQuestion = text
        errorMessage = nil
        isLoading = true
        speech.stop()
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let value = try await WatchAPIClient.shared.voice(
                    message: text,
                    context: context
                )
                reply = value
                question = ""
                if speech.shouldAutoSpeak(mode: speechMode) {
                    speech.speak(value.speechText)
                }
            } catch let error as WatchAPIError {
                errorMessage = error.message
                reply = nil
            } catch {
                errorMessage = "教练暂时联系不上，请稍后重试"
                reply = nil
            }
        }
    }
}
