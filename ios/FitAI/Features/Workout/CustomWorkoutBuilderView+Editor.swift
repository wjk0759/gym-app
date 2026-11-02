import SwiftUI

extension CustomWorkoutBuilderView {
    func metaText(_ info: Exercise?) -> String {
        guard let info else { return "" }
        return "\(info.muscle.label) · \(info.equipment.label)"
    }

    func exerciseEditor(index: Int) -> some View {
        let item = exercises[index]
        let info = item.exercise

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 24, height: 36)
                    .contentShape(Rectangle())
                    .draggable(item.id.uuidString)
                    .accessibilityLabel("拖动排序")

                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 30, height: 30)
                    .background(
                        Theme.ink.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(info?.nameZH ?? item.slug)
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Text(metaText(info))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                iconButton("trash", label: "移除", destructive: true) {
                    remove(index)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7)
            ], spacing: 8) {
                WheelPickerField(
                    title: "组数 · 组",
                    selection: $exercises[index].sets,
                    options: WorkoutPickerOptions.sets,
                    display: { "\($0)" }
                )
                WheelPickerField(
                    title: "每组次数 · 次",
                    selection: $exercises[index].reps,
                    options: WorkoutPickerOptions.reps,
                    display: { $0 }
                )
                WeightInputField(
                    title: "目标重量",
                    weight: weightBinding(index)
                )
                WheelPickerField(
                    title: "组间休息 · 秒",
                    selection: $exercises[index].restSec,
                    options: WorkoutPickerOptions.rests(including: exercises[index].restSec),
                    display: { "\($0)" }
                )
            }
        }
        .padding(11)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let raw = items.first,
                let id = UUID(uuidString: raw),
                let source = exercises.firstIndex(where: { $0.id == id }),
                source != index
            else { return false }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                let moved = exercises.remove(at: source)
                exercises.insert(moved, at: min(index, exercises.count))
            }
            Haptics.select()
            return true
        }
    }

    func iconButton(
        _ systemName: String,
        label: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destructive ? Theme.coral : Theme.secondaryText)
                .frame(width: 32, height: 32)
                .background(
                    Theme.ink.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .disabled(disabled)
        .opacity(disabled ? 0.26 : 1)
        .accessibilityLabel(label)
    }

    func weightBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { exercises[index].weightKG ?? 0 },
            set: { weight in
                exercises[index].weightKG = weight > 0 ? weight : nil
            }
        )
    }
}
