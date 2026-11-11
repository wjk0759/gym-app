import SwiftUI

/// The "data" half of the workout pager: today's completed sets, history,
/// RPE and the two recovery actions. The actual weight/reps controls live in
/// the fixed logger below the pager.
struct WorkoutSessionDataPage: View {
    let exercise: PlanExercise
    let logs: [SetLog]
    let lastSet: SetLog?
    let bestSet: SetLog?
    @Binding var rpe: Double
    let canSubstitute: Bool
    let canUndo: Bool
    let onUseLast: () -> Void
    let onSubstitute: () -> Void
    let onUndo: () -> Void

    private var completedLogs: [SetLog] {
        logs.filter { $0.slug == exercise.slug }
    }

    private var done: Int {
        completedLogs.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                todayCard
                historyCard
                rpeCard

                if canSubstitute {
                    substituteButton
                }

                if canUndo {
                    undoButton
                }
            }
            .appPagePadding()
            .padding(.top, 10)
            .padding(.bottom, 18)
            .appReadableContent()
        }
        .scrollIndicators(.hidden)
        .id(exercise.id)
    }

    // MARK: - 今天

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("今天")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 6)

                Text("\(done)/\(exercise.sets) 组")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.tertiaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            VStack(spacing: 5) {
                ForEach(completedLogs) { log in
                    completedRow(log)
                }

                if done < exercise.sets {
                    currentRow
                } else {
                    finishedRow
                }
            }
            .motionAnimation(Motion.quick, value: done)
        }
        .workoutLogCard()
    }

    private func completedRow(_ log: SetLog) -> some View {
        HStack(spacing: 7) {
            Text("第 \(log.setIndex) 组")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            Text(loadText(log))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(Theme.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Theme.onPrimary)
            }
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var currentRow: some View {
        HStack(spacing: 7) {
            Text("第 \(done + 1) 组")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            Text("进行中")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(Theme.ink.opacity(0.075))
                    .frame(width: 15, height: 15)
                Circle()
                    .fill(Theme.ink)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            Theme.primary.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var finishedRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("本动作已完成")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(
            Theme.primary.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    // MARK: - 历史

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("历史")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 6)

                if lastSet != nil {
                    Button {
                        Haptics.select()
                        onUseLast()
                    } label: {
                        Text("用上次")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(
                                Theme.primary.opacity(0.26),
                                in: Capsule(style: .continuous)
                            )
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.95))
                    .accessibilityLabel("使用上次的重量和次数")
                }
            }

            HStack(spacing: 6) {
                historyCell("上次", value: historyValue(lastSet))
                historyCell("最佳", value: historyValue(bestSet))
            }
        }
        .workoutLogCard()
    }

    private func historyCell(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)

            Text(value)
                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    // MARK: - RPE

    private var rpeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("主观强度 RPE")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 6)

                Text("8 = 还能做 2 次")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                rpeButton(symbol: "minus", enabled: rpe > 6) {
                    rpe = max(6, rpe - 0.5)
                }

                Text(rpe.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .frame(minWidth: 48)
                    .contentTransition(.numericText())

                rpeButton(symbol: "plus", enabled: rpe < 10) {
                    rpe = min(10, rpe + 0.5)
                }

                Spacer(minLength: 0)
            }
            .motionAnimation(Motion.quick, value: rpe)
        }
        .workoutLogCard()
    }

    private func rpeButton(
        symbol: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(
                    enabled ? Theme.ink : Theme.tertiaryText.opacity(0.35)
                )
                .frame(width: 30, height: 30)
                .background(
                    SoftSurface(
                        cornerRadius: 9,
                        tint: Theme.ink.opacity(0.04),
                        stroke: Theme.stroke
                    )
                )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.93))
        .disabled(!enabled)
        .accessibilityLabel(symbol == "minus" ? "降低 RPE" : "提高 RPE")
    }

    // MARK: - 链接

    private var substituteButton: some View {
        Button {
            Haptics.tap()
            onSubstitute()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))

                Text("器械被占了？换一个")
                    .font(.system(size: 10.5, weight: .semibold))

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.cobalt)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                Theme.cobalt.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.cobalt.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(SubtlePressStyle())
    }

    private var undoButton: some View {
        Button {
            Haptics.tap()
            onUndo()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))

                Text("撤销上一组")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Theme.tertiaryText)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Format

    private func historyValue(_ log: SetLog?) -> String {
        guard let log else { return "—" }
        return loadText(log)
    }

    private func loadText(_ log: SetLog) -> String {
        if log.weightKG > 0 {
            return "\(WorkoutWeightFormat.text(log.weightKG)) kg × \(log.reps)"
        }
        return "自重 × \(log.reps)"
    }
}

private extension View {
    /// Compact paper card used by the dense workout data page.
    func workoutLogCard(
        padding: CGFloat = 12,
        radius: CGFloat = 16
    ) -> some View {
        self
            .padding(padding)
            .background(
                Theme.paper,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }
}
