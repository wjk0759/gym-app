import SwiftUI

/// 动作维度的历史与 PR，补上“记录之后能看懂自己有没有进步”这一块。
struct ExerciseProgressView: View {
    @Environment(AppStore.self) private var store

    let slug: String

    @State private var selectedSession: WorkoutSession?

    init(slug: String) {
        self.slug = slug
    }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let volume: Double
    }

    private var exercise: Exercise? {
        ExerciseLibrary.exercise(slug: slug)
    }

    private var points: [Point] {
        Array(
            store.sessions
                .compactMap { session -> Point? in
                    let sets = session.sets.filter { $0.slug == slug && $0.completed }
                    guard !sets.isEmpty else { return nil }
                    return Point(
                        date: session.date,
                        volume: sets.reduce(0) { $0 + $1.weightKG * Double($1.reps) }
                    )
                }
                .sorted { $0.date < $1.date }
                .suffix(8)
        )
    }

    private var maxVolume: Double {
        max(1, points.map(\.volume).max() ?? 1)
    }

    private var history: [WorkoutSession] {
        store.sessions
            .filter { session in
                session.sets.contains { $0.slug == slug && $0.completed }
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                bestCard
                chartCard
                historyCard
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(AppBackground())
        .navigationTitle(exercise?.nameZH ?? "动作历史")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise?.nameZH ?? slug)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Text("共 \(history.count) 次训练记录")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var bestCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("历史最佳", systemImage: "crown.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)

            if let best = store.bestSet(for: slug) {
                Text(best.weightKG > 0
                     ? "\(best.weightKG.formatted()) kg × \(best.reps) 次"
                     : "自重 × \(best.reps) 次")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("RPE \(best.rpe.formatted(.number.precision(.fractionLength(1))))")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                Text("完成这个动作后，这里会记录你的 PR。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练容量趋势")
                .font(.headline)

            if points.isEmpty {
                Text("还没有足够的历史数据。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points) { point in
                        VStack(spacing: 5) {
                            Text("\(Int(point.volume))")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Theme.tertiaryText)
                                .lineLimit(1)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Theme.accent.opacity(0.75))
                                .frame(height: CGFloat(max(8, 92 * point.volume / maxVolume)))
                            Text(point.date.formatted(.dateTime.month().day()))
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.tertiaryText)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)

                Text("按每次训练中该动作的容量计算：重量 × 次数。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("历史记录")
                .font(.headline)

            if history.isEmpty {
                Text("还没有记录过这个动作。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(history) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                Text(session.dayTitle)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(session.sets.filter { $0.slug == slug && $0.completed }.count) 组")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                                Text("\(Int(session.sets.filter { $0.slug == slug && $0.completed }.reduce(0) { $0 + $1.weightKG * Double($1.reps) })) kg")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    if session.id != history.last?.id {
                        Divider().overlay(Theme.stroke)
                    }
                }
            }
        }
        .card()
    }
}
