import SwiftUI

struct WorkoutExerciseGroup: Identifiable {
    let slug: String
    var sets: [SetLog]

    var id: String { slug }
}

enum WorkoutFeeling {
    static func emoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "💪"
        }
    }

    static func text(_ value: Int) -> String {
        switch value {
        case 1: return "很吃力"
        case 2: return "有点累"
        case 3: return "一般"
        case 4: return "状态不错"
        default: return "状态很好"
        }
    }
}

struct WorkoutSummaryCard: View {
    let session: WorkoutSession

    var body: some View {
VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("SESSION / 训练详情")
                    .font(AppType.overline)
                    .tracking(1.3)
                    .foregroundStyle(Theme.cobalt)

                Spacer(minLength: 4)

                Text(session.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(String(session.dayTitle.prefix(40)))
                .lineLimit(2)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(session.date.formatted(date: .complete, time: .shortened))
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                EditorialMetric(
                    title: "时长",
                    value: "\(session.durationMinutes)",
                    unit: "分钟"
                )
                EditorialMetric(
                    title: "组数",
                    value: "\(session.sets.count)",
                    unit: "组"
                )
                EditorialMetric(
                    title: "容量",
                    value: "\(Int(session.volume))",
                    unit: "kg"
                )
            }

            HStack(spacing: 8) {
                Text(WorkoutFeeling.emoji(session.feeling))
                    .font(.system(size: 19))
                Text(WorkoutFeeling.text(session.feeling))
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("训练感受")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(10)
            .background(Theme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            if let notes = session.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.cobalt)
                        .frame(width: 3, height: 16)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("训练心得")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.cobalt)
                        Text(String(notes.prefix(300)))
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .editorialCard(accent: Theme.lime)
    }
}

struct WorkoutExerciseCard: View {
    let group: WorkoutExerciseGroup

    var body: some View {
let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    ExerciseProgressView(slug: group.slug)
                } label: {
                    Label("历史", systemImage: "chart.xyaxis.line")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))

                Text("\(group.sets.count) 组")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.primary, in: Capsule(style: .continuous))
            }

            InkDivider()

            ForEach(group.sets) { item in
                HStack(spacing: 9) {
                    Text("\(item.setIndex)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .background(Theme.ink.opacity(0.05), in: Circle())

                    Text(item.weightKG > 0
                         ? "\(item.weightKG.formatted()) kg × \(item.reps)"
                         : "自重 × \(item.reps)")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()

                    Spacer(minLength: 4)

                    Text("RPE \(item.rpe.formatted(.number.precision(.fractionLength(1))))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.vertical, 3)
            }
        }
        .card()
    }
}
