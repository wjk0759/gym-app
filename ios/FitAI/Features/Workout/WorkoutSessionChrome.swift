import SwiftUI

/// The two glanceable pages of an active workout. The set logger stays fixed
/// below both pages, so switching pages never interrupts logging.
enum WorkoutSessionPage: String, CaseIterable, Identifiable, Hashable {
    case data
    case demo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .data: return "数据"
        case .demo: return "演示"
        }
    }
}

/// Compact exercise identity row. Replaces the old editorial exercise card:
/// the page tabs and logger already carry the set context, so this only keeps
/// the name, equipment and target visible.
struct WorkoutSessionExerciseHeader: View {
    let exercise: PlanExercise
    let periodMode: PeriodTrainingMode?
    let onAdjust: () -> Void

    private var volumeText: String {
        if exercise.reps.contains("秒") {
            return "\(exercise.displayReps) 秒"
        }
        return "\(exercise.reps.replacingOccurrences(of: "-", with: "–")) 次"
    }

    private var targetText: String {
        let rpe = exercise.rpe.formatted(
            .number.precision(.fractionLength(1))
        )
        return "\(exercise.sets) 组 × \(volumeText) · RPE \(rpe)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.displayName)
                    .font(.system(size: 24, weight: .black))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 6) {
                    if let equipment = exercise.exercise?.equipment {
                        Text(equipment.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.tertiaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Theme.ink.opacity(0.045),
                                in: Capsule(style: .continuous)
                            )
                    }

                    Text(targetText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    if periodMode == .light {
                        Text("经期轻量")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.cycle)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Theme.cycle.opacity(0.10),
                                in: Capsule(style: .continuous)
                            )
                    }
                }

                if periodMode == .light {
                    Text("自动少 1 组、负重约 80%。腹痛明显时请改为散步或休息。")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.cycle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            Button {
                Haptics.tap()
                onAdjust()
            } label: {
                Text("调整")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .background(
                        Theme.paper,
                        in: Capsule(style: .continuous)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .buttonStyle(SubtlePressStyle(scale: 0.95))
            .accessibilityHint("调整本次训练的组数、次数、重量和休息")
        }
        .appPagePadding()
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}

/// Two-segment page control with a sliding ink capsule and a lime signal dot.
struct WorkoutSessionPageTabs: View {
    @Binding var selection: WorkoutSessionPage
    @Namespace private var indicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(WorkoutSessionPage.allCases) { page in
                Button {
                    guard selection != page else { return }
                    withAnimation(
                        Motion.resolved(
                            Motion.smooth,
                            reduceMotion: reduceMotion
                        )
                    ) {
                        selection = page
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Theme.primary)
                            .frame(width: 5, height: 5)
                            .opacity(selection == page ? 1 : 0)
                            .scaleEffect(selection == page ? 1 : 0.5)

                        Text(page.title)
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(
                        selection == page
                            ? Theme.onAccent
                            : Theme.secondaryText
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background {
                        if selection == page {
                            RoundedRectangle(
                                cornerRadius: 9,
                                style: .continuous
                            )
                            .fill(Theme.ink)
                            .matchedGeometryEffect(
                                id: "session-page",
                                in: indicator
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(page.title)页")
                .accessibilityAddTraits(
                    selection == page ? [.isSelected] : []
                )
            }
        }
        .padding(3)
        .background(
            Theme.ink.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .motionAnimation(Motion.quick, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
        .appPagePadding()
        .padding(.bottom, 8)
        .background(Theme.background)
    }
}
