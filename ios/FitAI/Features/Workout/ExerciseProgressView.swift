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
                    let sets = completedSets(in: session)
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
            .filter { !completedSets(in: $0).isEmpty }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                bestCard
                chartCard
                historyCard
            }
            .appPagePadding()
            .appPageTopPadding()
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("动作历史")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("EXERCISE / 动作历史")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text(exercise?.nameZH ?? slug)
                .font(AppType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "") · \(history.count) 次记录")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - PR

    private var bestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("历史最佳")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 0)
            }

            if let best = store.bestSet(for: slug) {
                Text(best.weightKG > 0
                     ? "\(best.weightKG.formatted()) kg × \(best.reps) 次"
                     : "自重 × \(best.reps) 次")
                    .font(AppType.hero)
                    .tracking(-0.5)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("RPE \(best.rpe.formatted(.number.precision(.fractionLength(1))))")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            } else {
                Text("完成这个动作后，这里会记录你的 PR。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.lime)
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("训练容量趋势")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 4)
                Text("最近 \(points.count) 次")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if points.isEmpty {
                Text("还没有足够的历史数据。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(points) { point in
                        VStack(spacing: 5) {
                            Text("\(Int(point.volume))")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(point.id == points.last?.id ? Theme.lime : Theme.cobalt)
                                .frame(height: CGFloat(max(8, 92 * point.volume / maxVolume)))

                            Text(point.date.formatted(.dateTime.month().day()))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Theme.tertiaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)

                Text("按每次训练中该动作的容量计算：重量 × 次数。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .card()
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("历史记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 4)
                Text("\(history.count) 次")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if history.isEmpty {
                Text("还没有记录过这个动作。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(history) { session in
                    Button {
                        Haptics.tap()
                        selectedSession = session
                    } label: {
                        historyRow(session)
                    }
                    .buttonStyle(.plain)

                    if session.id != history.last?.id {
                        InkDivider()
                    }
                }
            }
        }
        .card()
    }

    private func historyRow(_ session: WorkoutSession) -> some View {
        let sets = completedSets(in: session)
        let volume = sets.reduce(0) { $0 + $1.weightKG * Double($1.reps) }

        return HStack(spacing: 10) {
            VStack(spacing: 0) {
                Text("\(Calendar.current.component(.day, from: session.date))")
                    .font(.system(size: 17, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                Text("\(Calendar.current.component(.month, from: session.date))月")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .frame(width: 38, height: 42)
            .background(
                Theme.ink.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(session.dayTitle.prefix(40)))
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(sets.count) 组 · \(Int(volume)) kg")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 4)

            Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    private func completedSets(in session: WorkoutSession) -> [SetLog] {
        session.sets.filter { $0.slug == slug && $0.completed }
    }
}
