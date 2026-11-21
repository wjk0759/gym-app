import SwiftUI

/// 训练页内嵌教练：不离开训练页，只问当前动作的只读建议。
/// 写操作仍会落到教练控制面的待确认卡，用户需要回教练页确认。
struct WorkoutCoachSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// 当前动作的实时快照；训练刚开始还没有草稿时也能用。
    let activeWorkout: [String: Any]?

    @State private var input = ""
    @FocusState private var focused: Bool

    private let quickPrompts = ["下一组怎么练", "这个重量行吗", "还要练几组"]
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("教练会看到当前动作、已完成组数和上一组 RPE。需要改计划时会提示你回教练页确认。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(quickPrompts, id: \.self) { prompt in
                            Button(prompt) {
                                send(prompt)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(store.isWorkoutCoachWorking)
                        }
                    }

                    if store.isWorkoutCoachWorking {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Theme.cobalt)
                            Text("教练在想...")
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    } else if let reply = store.workoutCoachReply {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("教练")
                                .font(AppType.micro.weight(.semibold))
                                .foregroundStyle(Theme.cobalt)
                            Text(reply)
                                .font(AppType.callout)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            Theme.cobalt.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    } else {
                        Text("可以直接问：“下一组怎么练”“这个重量行吗”。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    HStack(spacing: 8) {
                        TextField("问教练...", text: $input)
                            .textFieldStyle(.roundedBorder)
                            .focused($focused)
                            .submitLabel(.send)
                            .onSubmit { send(input) }
                        Button {
                            send(input)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.cobalt)
                        }
                        .disabled(
                            input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || store.isWorkoutCoachWorking
                        )
                        .accessibilityLabel("发送")
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("训练中教练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !store.isWorkoutCoachWorking else { return }
        input = ""
        focused = false
        store.askWorkoutCoach(trimmed, activeWorkout: activeWorkout)
    }
}
