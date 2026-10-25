import Combine
import SwiftUI
import UIKit

struct WorkoutSessionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let day: PlanDay

    @State private var index = 0
    @State private var logs: [SetLog] = []
    @State private var weight: Double = 0
    @State private var reps: Int = 10
    @State private var rpe: Double = 7.5
    @State private var restRemaining: Int?
    @State private var feeling = 4
    @State private var startedAt = Date()
    @State private var showExitConfirm = false
    @State private var showEmptySaveAlert = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                ScrollView {
                        VStack(spacing: 16) {
                            if let restRemaining {
                                restCard(restRemaining)
                            }

                            if let exercise = currentExercise {
                                exerciseCard(exercise)
                                setCard(exercise)
                            } else {
                                summaryCard
                            }
                        }
                        .padding(20)
                        .padding(.bottom, 24)
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    workoutActionBar
                }
            .background(AppBackground())
            .navigationTitle("训练中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("结束") { showExitConfirm = true }
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                startedAt = Date()
                prepare(day.exercises.first)
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onReceive(timer) { _ in
                tickRest()
            }
            .confirmationDialog(
                "结束这次训练？",
                isPresented: $showExitConfirm,
                titleVisibility: .visible
            ) {
                Button("结束并保存", role: .destructive) { finish() }
                Button("继续训练", role: .cancel) {}
            } message: {
                Text("已完成的 \(logs.count) 组会保存到训练记录。")
            }
            .alert("还没有训练记录", isPresented: $showEmptySaveAlert) {
                Button("继续训练", role: .cancel) {}
                Button("放弃并退出", role: .destructive) { dismiss() }
            } message: {
                Text("至少完成一组后再保存，避免产生一条 0 组的空训练记录。")
            }
        }
    }

    // MARK: - 顶部进度

    private var progressHeader: some View {
        let totalSets = day.exercises.reduce(0) { $0 + $1.sets }
        let progress = Double(logs.count) / Double(max(1, totalSets))

        return VStack(spacing: 8) {
            HStack {
                Text("\(logs.count)/\(totalSets) 组")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(min(index + 1, day.exercises.count))/\(day.exercises.count) 动作")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
            ProgressView(value: min(1, progress))
                .tint(Theme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - 当前动作

    private var currentExercise: PlanExercise? {
        guard day.exercises.indices.contains(index) else { return nil }
        return day.exercises[index]
    }

    private func completedSets(for exercise: PlanExercise) -> Int {
        logs.filter { $0.slug == exercise.slug }.count
    }

    private func exerciseCard(_ exercise: PlanExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("动作 \(index + 1)/\(day.exercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if let equipment = exercise.exercise?.equipment {
                    Text(equipment.label)
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Text(exercise.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(exercise.targetText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.accent)

            if let instructions = exercise.exercise?.instructions {
                Text(instructions)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func setCard(_ exercise: PlanExercise) -> some View {
        let done = completedSets(for: exercise)
        let isBodyweight = exercise.exercise?.equipment == .bodyweight

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("第 \(min(done + 1, exercise.sets)) 组 / 共 \(exercise.sets) 组")
                    .font(.headline)
                Spacer()
                Text("目标 RPE \(exercise.rpe, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            if let last = store.lastSet(for: exercise.slug) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("上次 \(last.weightKG > 0 ? "\(last.weightKG.formatted()) kg × \(last.reps)" : "自重 × \(last.reps)") · RPE \(last.rpe.formatted(.number.precision(.fractionLength(1))))")
                }
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            }

            if !isBodyweight {
                HStack {
                    Text("重量")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Stepper(value: $weight, in: 0...300, step: 2.5) {
                        Text("\(weight, specifier: "%.1f") kg")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(minWidth: 96, alignment: .trailing)
                    }
                }
            }

            HStack {
                Text("次数")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Stepper(value: $reps, in: 1...60) {
                    Text("\(reps) 次")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minWidth: 80, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("主观强度 RPE")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(rpe.formatted(.number.precision(.fractionLength(1))))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Slider(value: $rpe, in: 6...10, step: 0.5)
                    .tint(Theme.accent)
                Text("6 = 很轻松 · 8 = 还能做 2 次 · 10 = 力竭")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if done > 0,
               let last = logs.last,
               last.slug == exercise.slug {
                Button("撤销上一组") {
                    logs.removeLast()
                    restRemaining = nil
                }
                .font(.caption)
                .foregroundStyle(Theme.warning)
            }
        }
        .card()
    }

    private var workoutActionBar: some View {
        VStack(spacing: 8) {
            if let exercise = currentExercise {
                let done = completedSets(for: exercise)

                HStack {
                    Button("跳过这个动作") {
                        advance()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)

                    Spacer()

                    if done > 0 {
                        Text("已完成 \(done) 组")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }

                if done < exercise.sets {
                    Button("完成第 \(done + 1) 组") {
                        completeSet(exercise)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(nextTitle) {
                        advance()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button("保存并结束") {
                    finish()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }

    private var nextTitle: String {
        index < day.exercises.count - 1 ? "下一个动作" : "查看训练总结"
    }

    private func restCard(_ remaining: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .foregroundStyle(Theme.accent)
            Text("休息 \(remaining)s")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Button("跳过") {
                restRemaining = nil
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .card(padding: 14)
    }

    // MARK: - 总结

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练完成")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                summaryMetric("\(logs.count)", "完成组数")
                summaryMetric("\(Int(logs.reduce(0.0) { $0 + $1.weightKG * Double($1.reps) }))", "总容量 kg")
                summaryMetric("\(durationMinutes)", "分钟")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("今天感觉如何？")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            feeling = value
                        } label: {
                            Text(feelingEmoji(value))
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(feeling == value ? Theme.accent.opacity(0.18) : Theme.surfaceStrong)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("记录会用于下一次计划调整。至少完成一组再保存，AI 才能判断负荷。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func summaryMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var durationMinutes: Int {
        max(1, Int(Date().timeIntervalSince(startedAt) / 60))
    }

    // MARK: - 行为

    private func prepare(_ exercise: PlanExercise?) {
        guard let exercise else { return }
        weight = exercise.weightKG ?? 0
        let firstComponent = exercise.reps.components(separatedBy: "-").first ?? ""
        let digits = firstComponent.filter { $0.isNumber }
        reps = Int(digits) ?? 10
        rpe = exercise.rpe

        if let last = store.lastSet(for: exercise.slug) {
            weight = last.weightKG
            reps = last.reps
        }
    }

    private func completeSet(_ exercise: PlanExercise) {
        let nextIndex = completedSets(for: exercise) + 1
        let isBodyweight = exercise.exercise?.equipment == .bodyweight
        logs.append(
            SetLog(
                slug: exercise.slug,
                setIndex: nextIndex,
                weightKG: isBodyweight ? 0 : weight,
                reps: reps,
                rpe: rpe
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        restRemaining = exercise.restSec > 0 ? exercise.restSec : nil
    }

    private func advance() {
        restRemaining = nil
        if index < day.exercises.count - 1 {
            index += 1
            prepare(day.exercises[index])
        } else {
            index = day.exercises.count
        }
    }

    private func tickRest() {
        guard let remaining = restRemaining else { return }
        if remaining <= 1 {
            restRemaining = nil
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            restRemaining = remaining - 1
        }
    }

    private func finish() {
        guard !logs.isEmpty else {
            showEmptySaveAlert = true
            return
        }
        store.record(
            day: day,
            sets: logs,
            durationMinutes: durationMinutes,
            feeling: feeling
        )
        dismiss()
    }

    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "💪"
        }
    }
}
