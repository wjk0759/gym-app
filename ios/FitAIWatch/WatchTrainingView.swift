import Combine
import SwiftUI
import FitAIWorkoutCore

/// Watch-side workout controls. This is intentionally a thin surface over the
/// shared engine; no workout rules live in the view.
struct WatchTrainingView: View {
    @State private var engine = WatchWorkoutPreview.engine
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                if let exercise = engine.snapshot.currentExercise {
                    exerciseCard(exercise)
                    if let remaining = engine.snapshot.remainingRest(at: now) {
                        restCard(remaining)
                    }
                    controls(exercise)
                } else {
                    summary
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .onReceive(timer) { value in
            now = value
        }
    }

    private var header: some View {
        HStack {
            Text("训练")
                .font(.headline)
            Spacer()
            if engine.snapshot.isPaused {
                Text("已暂停")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Text("\(engine.snapshot.completedSetCount)/\(engine.snapshot.plannedSetCount) 组")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exerciseCard(_ exercise: WorkoutExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
                .lineLimit(2)
            Text(
                "\(engine.snapshot.currentSetIndex(for: exercise))/\(exercise.sets) 组"
                + " · \(targetText(exercise.target))"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            if let weight = exercise.weightKG, weight > 0 {
                Text("\(weight.formatted(.number.precision(.fractionLength(0...1)))) kg")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }
            if let next = engine.snapshot.nextExercise {
                Text("下一个：\(next.name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func restCard(_ remaining: TimeInterval) -> some View {
        HStack {
            Image(systemName: "timer")
            Text(format(remaining))
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Spacer()
            Button("跳过") {
                apply(.skipRest(.init(at: now, source: .watch)))
            }
            .buttonStyle(.bordered)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func controls(_ exercise: WorkoutExercise) -> some View {
        VStack(spacing: 6) {
            Button {
                completeSet(exercise)
            } label: {
                Label("完成一组", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            HStack(spacing: 6) {
                Button {
                    if engine.snapshot.isPaused {
                        apply(.resume(.init(at: now, source: .watch)))
                    } else {
                        apply(.pause(.init(at: now, source: .watch)))
                    }
                } label: {
                    Label(
                        engine.snapshot.isPaused ? "继续" : "暂停",
                        systemImage: engine.snapshot.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.bordered)

                Button {
                    apply(.undoLastSet(.init(at: now, source: .watch)))
                } label: {
                    Label("撤销", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
            }

            if engine.snapshot.isExerciseComplete(exercise) {
                Button("下一个动作") {
                    apply(.advanceExercise(.init(at: now, source: .watch)))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("训练完成")
                .font(.headline)
            Text("\(engine.snapshot.completedSetCount) 组")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("结束训练") {
                apply(.finish(.init(at: now, source: .watch)))
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func completeSet(_ exercise: WorkoutExercise) {
        let setIndex = engine.snapshot.currentSetIndex(for: exercise)
        let reps: Int?
        let seconds: Int?
        switch exercise.target {
        case .reps(let min, _):
            reps = min
            seconds = nil
        case .time(let value):
            reps = nil
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
        do {
            _ = try engine.apply(command)
            now = Date()
        } catch {
            // The production surface will map engine errors to watch haptics
            // and a short message; keep the preview non-blocking for now.
        }
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

/// A deterministic preview day until the watch bootstrap endpoint is wired.
enum WatchWorkoutPreview {
    static var engine: WorkoutSessionEngine {
        let exercises = [
            WorkoutExercise(
                slug: "bench_press",
                name: "哑铃卧推",
                target: .reps(min: 8, max: 10),
                sets: 3,
                weightKG: 60,
                restSeconds: 90,
                equipment: "哑铃"
            ),
            WorkoutExercise(
                slug: "plank",
                name: "平板支撑",
                target: .time(seconds: 30),
                sets: 3,
                weightKG: nil,
                restSeconds: 45,
                isBodyweight: true,
                equipment: "自重"
            )
        ]
        let snapshot = WorkoutSessionSnapshot(
            programDayID: UUID(),
            dayTitle: "推",
            startedAt: Date(),
            exercises: exercises
        )
        return WorkoutSessionEngine(snapshot: snapshot)
    }
}
