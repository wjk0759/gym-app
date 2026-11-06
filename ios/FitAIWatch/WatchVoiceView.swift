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
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                header
                TextFieldLink(
                    "问教练…",
                    prompt: Text("听写或手写")
                ) { text in
                    question = text
                    send(text)
                }
                .font(.caption)
                .disabled(isLoading)

                Button {
                    send()
                } label: {
                    Label(
                        isLoading ? "思考中…" : "发送",
                        systemImage: isLoading ? "ellipsis" : "paperplane.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || question.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty)

                if !lastQuestion.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("你问")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(lastQuestion)
                            .font(.caption)
                    }
                }

                if isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("教练正在看你的训练")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let reply {
                    answer(reply)
                }

                Text("只读回答。改计划、加减组数请到 iPhone 确认。")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .navigationTitle("语音教练")
        .sheet(isPresented: $showSettings) {
            speechSettings
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "waveform")
                .foregroundStyle(.yellow)
            Text("叫练 · 训练中")
                .font(.caption.weight(.semibold))
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "speaker.wave.2")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func answer(_ reply: WatchVoiceReply) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if reply.requiresPhoneConfirmation {
                Label("需要 iPhone 确认", systemImage: "iphone")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            if reply.safetyFlag != nil {
                Label("先看安全提示", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text(reply.reply)
                .font(.body)
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
                .font(.caption2)
                Spacer()
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var speechSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("朗读方式")
                    .font(.headline)
                ForEach(WatchSpeechMode.allCases) { mode in
                    Button {
                        speechModeRaw = mode.rawValue
                    } label: {
                        HStack {
                            Text(mode.title)
                                .font(.caption)
                            Spacer()
                            if speechMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 3)
                }
                Text("默认静音。点“朗读”始终可用；耳机模式只在连接耳机时自动读。")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("完成") {
                    showSettings = false
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 2)
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
