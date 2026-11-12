import SwiftUI

/// Post-workout comparison: planned vs completed, previous session, PR and the
/// next load suggestion. This is intentionally derived from local history so it
/// works immediately after finishing, even before the workout syncs.
struct WorkoutOutcomeCard: View {
    @Environment(AppStore.self) private var store

    let exercises: [PlanExercise]
    let logs: [SetLog]

    private struct ExerciseOutcome: Identifiable {
        let id: String
        let name: String
        let plannedSets: Int
        let completedSets: Int
        let currentVolume: Double
        let previousVolume: Double?
        let currentBest: SetLog?
        let previousBest: SetLog?
        let isPR: Bool
        let suggestion: String
    }

    private var outcomes: [ExerciseOutcome] {
        exercises.compactMap { exercise in
            let sets = logs.filter { $0.slug == exercise.slug && $0.completed }
            guard !sets.isEmpty else { return nil }
            let previousSession = store.sessions
                .sorted { $0.date > $1.date }
                .first { session in
                    session.sets.contains { $0.slug == exercise.slug && $0.completed }
                }
            let previousSets = previousSession?.sets.filter {
                $0.slug == exercise.slug && $0.completed
            } ?? []
            let currentBest = sets.max { left, right in
                if left.weightKG != right.weightKG {
                    return left.weightKG < right.weightKG
                }
                return left.reps < right.reps
            }
            let previousBest = store.bestSet(for: exercise.slug)
            let isPR: Bool = {
                guard let currentBest, let previousBest else { return false }
                return isBetter(currentBest, previousBest)
            }()
            return ExerciseOutcome(
                id: exercise.slug,
                name: exercise.displayName,
                plannedSets: max(1, exercise.sets),
                completedSets: sets.count,
                currentVolume: volume(sets),
                previousVolume: previousSession == nil ? nil : volume(previousSets),
                currentBest: currentBest,
                previousBest: previousBest,
                isPR: isPR,
                suggestion: suggestion(
                    exercise: exercise,
                    sets: sets,
                    planned: max(1, exercise.sets)
                )
            )
        }
    }

    var body: some View {
        if !outcomes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("本次结果")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("计划 vs 实际")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }

                let planned = outcomes.reduce(0) { $0 + $1.plannedSets }
                let completed = outcomes.reduce(0) { $0 + $1.completedSets }
                HStack(spacing: 8) {
                    EditorialMetric(
                        title: "完成组",
                        value: "\(completed)/\(planned)",
                        unit: "组"
                    )
                    EditorialMetric(
                        title: "完成率",
                        value: "\(Int(Double(completed) / Double(max(1, planned)) * 100))",
                        unit: "%"
                    )
                    EditorialMetric(
                        title: "新 PR",
                        value: "\(outcomes.filter(\.isPR).count)",
                        unit: "个"
                    )
                }

                ForEach(outcomes.prefix(4)) { item in
                    outcomeRow(item)
                }

                Text("下次建议按本次完成度和 RPE 自动生成；疼痛或动作变形时优先降重量。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card()
        }
    }

    private func outcomeRow(_ item: ExerciseOutcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(item.name)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if item.isPR {
                    Text("PR")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.onPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.cobalt, in: Capsule())
                }

                Spacer(minLength: 4)

                Text("\(item.completedSets)/\(item.plannedSets) 组")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        item.completedSets >= item.plannedSets
                            ? Theme.ink
                            : Theme.coral
                    )
            }

            HStack(spacing: 8) {
                Text("本次 \(loadText(item.currentVolume, sets: item.completedSets))")
                if let previous = item.previousVolume {
                    Text("上次 \(loadText(previous, sets: item.completedSets))")
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.secondaryText)

            Text("下次：\(item.suggestion)")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.cobalt)
                .lineLimit(2)
        }
        .padding(10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func volume(_ sets: [SetLog]) -> Double {
        sets.reduce(0) { $0 + $1.weightKG * Double($1.reps) }
    }

    private func loadText(_ volume: Double, sets: Int) -> String {
        if volume <= 0 {
            return "\(sets) 组完成"
        }
        return "\(Int(volume)) kg"
    }

    private func isBetter(_ left: SetLog, _ right: SetLog) -> Bool {
        if left.weightKG != right.weightKG {
            return left.weightKG > right.weightKG
        }
        return left.reps > right.reps
    }

    private func suggestion(
        exercise: PlanExercise,
        sets: [SetLog],
        planned: Int
    ) -> String {
        let averageRPE = sets.isEmpty
            ? 0
            : sets.reduce(0) { $0 + $1.rpe } / Double(sets.count)
        if sets.count < planned {
            return "先补足 \(planned) 组，重量降 5%，不要硬顶"
        }
        if averageRPE >= 9 {
            return "降 5% 重量，把 RPE 控制在 8 左右"
        }
        if exercise.exercise?.equipment == .bodyweight {
            return "每组多做 1 次，动作变形就停"
        }
        return "动作稳定时加 2.5% 重量或每组多做 1 次"
    }
}
