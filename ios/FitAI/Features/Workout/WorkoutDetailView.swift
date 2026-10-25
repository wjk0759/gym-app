import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    private struct ExerciseGroup: Identifiable {
        let slug: String
        var sets: [SetLog]
        var id: String { slug }
    }

    private var groups: [ExerciseGroup] {
        var result: [ExerciseGroup] = []
        for log in session.sets {
            if let index = result.firstIndex(where: { $0.slug == log.slug }) {
                result[index].sets.append(log)
            } else {
                result.append(ExerciseGroup(slug: log.slug, sets: [log]))
            }
        }
        return result.map { group in
            var copy = group
            copy.sets.sort { $0.setIndex < $1.setIndex }
            return copy
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if groups.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet.clipboard",
                            title: "这次没有记录组数",
                            message: "下次训练时至少完成一组，才能看到容量和负荷。"
                        )
                    } else {
                        ForEach(groups) { group in
                            exerciseCard(group)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("训练详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.dayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(session.date.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 12) {
                metric("\(session.durationMinutes)", "分钟")
                metric("\(session.sets.count)", "组数")
                metric("\(Int(session.volume))", "容量 kg")
            }

            HStack {
                Text("训练感受")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(feelingEmoji(session.feeling))
                Text(feelingText(session.feeling))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }
        }
        .card()
    }

    private func metric(_ value: String, _ title: String) -> some View {
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

    private func exerciseCard(_ group: ExerciseGroup) -> some View {
        let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Text("\(group.sets.count) 组")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }

            ForEach(group.sets) { item in
                HStack {
                    Text("第 \(item.setIndex) 组")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 52, alignment: .leading)

                    Text(item.weightKG > 0
                         ? "\(item.weightKG.formatted()) kg × \(item.reps)"
                         : "自重 × \(item.reps)")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("RPE \(item.rpe.formatted(.number.precision(.fractionLength(1))))")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
        }
        .card()
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

    private func feelingText(_ value: Int) -> String {
        switch value {
        case 1: return "很吃力"
        case 2: return "有点累"
        case 3: return "一般"
        case 4: return "状态不错"
        default: return "状态很好"
        }
    }
}
