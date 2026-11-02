import SwiftUI

enum EquipmentPickerSymbols {
    static func muscle(_ muscle: MuscleGroup) -> String {
        switch muscle {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .legs: return "figure.step.training"
        case .glutes: return "figure.strengthtraining.functional"
        case .shoulders: return "figure.arms.open"
        case .arms: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        }
    }
}

struct EquipmentPickerExerciseCard: View {
    let exercise: Exercise
    let selected: Bool
    let isPickingForSession: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Theme.ink.opacity(0.04))
                    .frame(height: 102)

                Circle()
                    .fill(Theme.cobalt.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Theme.cobalt.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: EquipmentPickerSymbols.muscle(exercise.muscle))
                            .font(.system(size: 29, weight: .light))
                            .foregroundStyle(Theme.cobalt.opacity(0.9))
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(alignment: .topLeading) {
                if exercise.videoURL != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 6, weight: .bold))
                        Text("讲解")
                            .font(.system(size: 8.5, weight: .semibold))
                    }
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.42), in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(7)
                }
            }

            Text(exercise.nameZH)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.top, 9)

            HStack(spacing: 3) {
                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: isPickingForSession ? "plus.circle.fill" : "chevron.right")
                    .font(.system(size: isPickingForSession ? 13 : 9, weight: .semibold))
                    .foregroundStyle(isPickingForSession ? Theme.cobalt : Theme.tertiaryText.opacity(0.72))
            }
            .padding(.horizontal, 9)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .background(Theme.paper)
        .background(selected ? Theme.cobalt.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    selected ? Theme.cobalt.opacity(0.62) : Theme.stroke,
                    lineWidth: 1
                )
        )
        .animation(Motion.quick, value: selected)
    }
}

struct EquipmentPickerSelectionControl: View {
    let exercise: Exercise
    let selected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? Theme.cobalt : Color.black.opacity(0.42))
            Circle()
                .stroke(selected ? Theme.cobalt : Color.white.opacity(0.32), lineWidth: 1)
            Image(systemName: selected ? "checkmark" : "plus")
                .font(.system(size: selected ? 11 : 10, weight: .bold))
                .foregroundStyle(selected ? Theme.onAccent : Color.white.opacity(0.82))
        }
        .frame(width: 30, height: 30)
        .scaleEffect(selected ? 1.06 : 1)
        .animation(Motion.quick, value: selected)
        .contentShape(Circle())
        .accessibilityLabel(selected ? "取消选择\(exercise.nameZH)" : "选择\(exercise.nameZH)")
    }
}
