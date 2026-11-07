import Combine
import SwiftUI
import FitAIWorkoutCore

/// Watch-side workout controls. This is intentionally a thin surface over the
/// shared engine; no workout rules live in the view.
struct WatchTrainingView: View {
    let store: WatchWorkoutStore
    let onVoice: () -> Void

    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var snapshot: WorkoutSessionSnapshot {
        store.snapshot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                WatchProgressBar(
                    completed: snapshot.completedSetCount,
                    planned: snapshot.plannedSetCount
                )
                if snapshot.isFinished {
                    summary
                } else if let exercise = snapshot.currentExercise {
                    exerciseCard(exercise)
                    if let remaining = snapshot.remainingRest(at: now),
                       remaining > 0 {
                        restCard(remaining)
                    }
                    controls(exercise)
                } else {
                    summary
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
        .background(WatchTheme.canvas)
        .sensoryFeedback(.success, trigger: snapshot.completedSetCount)
        .onReceive(timer) { value in
            now = value
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("训练")
                .font(.headline)
                .foregroundStyle(WatchTheme.ink)
            Spacer(minLength: 4)
            Button(action: onVoice) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WatchTheme.onPrimary)
                    .frame(width: 28, height: 28)
                    .background(WatchTheme.primary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("语音教练")

            if snapshot.isPaused {
                Text("已暂停")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(WatchTheme.warning)
            } else {
                Text("\(snapshot.completedSetCount)/\(snapshot.plannedSetCount) 组")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(WatchTheme.secondary)
            }
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.headline)
                .foregroundStyle(WatchTheme.ink)
                .lineLimit(2)

            Text(
                "\(snapshot.currentSetIndex(for: exercise))/\(exercise.sets) 组"
                + " · \(targetText(exercise.target))"
            )
            .font(.caption2)
            .foregroundStyle(WatchTheme.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let weight = exercise.weightKG, weight > 0 {
                    Text(
                        weight.formatted(
                            .number.precision(.fractionLength(0...1))
                        )
                    )
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.ink)
                    Text("kg")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WatchTheme.secondary)
                }
                Spacer(minLength: 4)
                if let next = snapshot.nextExercise {
                    Text("下一个 \(next.name)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WatchTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WatchTheme.surface,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(WatchTheme.primary)
                .frame(width: 3)
                .padding(.vertical, 7)
                .padding(.leading, 1)
        }
    }

    private func restCard(_ remaining: TimeInterval) -> some View {
        let exercise = snapshot.currentExercise
        let isComplete = exercise.map { snapshot.isExerciseComplete($0) } ?? false

        return HStack(spacing: 6) {
            Image(systemName: "timer")
                .foregroundStyle(WatchTheme.primary)
            Text(format(remaining))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(WatchTheme.ink)
            Spacer(minLength: 4)
            if isComplete {
                Button("下一个动作") {
                    apply(.skipRest(.init(at: now, source: .watch)))
                    apply(.advanceExercise(.init(at: now, source: .watch)))
                }
                .buttonStyle(WatchCompactPrimaryButtonStyle())
            } else {
                Button("跳过") {
                    apply(.skipRest(.init(at: now, source: .watch)))
                }
                .buttonStyle(.bordered)
                .tint(WatchTheme.primary)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            WatchTheme.surface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func controls(_ exercise: WorkoutExercise) -> some View {
        // Match the iPhone action bar: the primary button is the next step,
        // not a second button beside "完成一组". During the final rest, the
        // rest card owns the "next exercise" action so it stays on screen.
        let isComplete = snapshot.isExerciseComplete(exercise)
        let isLast = snapshot.nextExercise == nil
        let isResting = (snapshot.remainingRest(at: now) ?? 0) > 0

        return Group {
            if !(isComplete && isResting) {
                HStack(spacing: 6) {
                    Button {
                        if isComplete {
                            apply(.advanceExercise(.init(at: now, source: .watch)))
                        } else {
                            completeSet(exercise)
                        }
                    } label: {
                        Label(
                            isComplete
                                ? (isLast ? "查看总结" : "下一个动作")
                                : "完成一组",
                            systemImage: isComplete ? "arrow.right" : "checkmark"
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WatchPrimaryButtonStyle())
                    .disabled(snapshot.isPaused)

                    Button {
                        if snapshot.isPaused {
                            apply(.resume(.init(at: now, source: .watch)))
                        } else {
                            apply(.pause(.init(at: now, source: .watch)))
                        }
                    } label: {
                        Image(
                            systemName: snapshot.isPaused
                                ? "play.fill"
                                : "pause.fill"
                        )
                    }
                    .buttonStyle(WatchIconButtonStyle())
                    .accessibilityLabel(
                        snapshot.isPaused ? "继续训练" : "暂停训练"
                    )

                    Button {
                        apply(.undoLastSet(.init(at: now, source: .watch)))
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(WatchIconButtonStyle())
                    .accessibilityLabel("撤销上一组")
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练完成")
                .font(.headline)
                .foregroundStyle(WatchTheme.ink)
            Text("\(snapshot.completedSetCount) 组")
                .font(.caption)
                .foregroundStyle(WatchTheme.secondary)
            if snapshot.isFinished {
                Text("已结束，稍后可在 iPhone 查看")
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.primary)
            } else {
                Button("结束训练") {
                    apply(.finish(.init(at: now, source: .watch)))
                }
                .buttonStyle(WatchPrimaryButtonStyle())
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            WatchTheme.surface,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func completeSet(_ exercise: WorkoutExercise) {
        let setIndex = snapshot.currentSetIndex(for: exercise)
        let reps: Int?
        let seconds: Int?
        switch exercise.target {
        case .reps(let min, _):
            reps = min
            seconds = nil
        case .time(let value):
            reps = value
            seconds = value
        }
        apply(
            .completeSet(
                .init(
                    exerciseID: exercise.id,
                    setIndex: setIndex,
                    weightKG: exercise.weightKG ?? 0,
                    reps: reps,
                    seconds: seconds,
                    at: now,
                    source: .watch
                )
            )
        )
    }

    private func apply(_ command: WorkoutCommand) {
        _ = store.apply(command)
        now = Date()
    }

    private func targetText(_ target: WorkoutExercise.Target) -> String {
        switch target {
        case .reps(let min, let max):
            return min == max ? "\(min) 次" : "\(min)–\(max) 次"
        case .time(let seconds):
            return "\(seconds) 秒"
        }
    }

    private func format(_ value: TimeInterval) -> String {
        let total = max(0, Int(value.rounded()))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
