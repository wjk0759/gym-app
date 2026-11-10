import SwiftUI

/// 器械页已选动作气泡：集中展示本次挑好的动作，并进入训练编排。
struct EquipmentSelectionPanelView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let exercises: [Exercise]
    let onRemove: (Exercise) -> Void
    let onClear: () -> Void
    let onMakePlan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            separator

            if exercises.isEmpty {
                emptyState
            } else {
                exerciseList
            }

            separator
            actionSection
        }
        .frame(minWidth: 260, idealWidth: 330, maxWidth: 380)
        .background(Theme.background)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("已选动作")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("\(exercises.count)")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.cobalt)
                }
                Text(exercises.isEmpty ? "还没有选择动作" : "选好后先安排顺序和负荷，再开始训练")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if !exercises.isEmpty {
                Button("清空", action: onClear)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .padding(16)
    }

    private var separator: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "dumbbell")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
            Text("还没有选择动作")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("在下面点选动作，再制作训练计划。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.vertical, 34)
    }

    private var exerciseList: some View {
        AppScrollView {
            LazyVStack(spacing: 0) {
                ForEach(exercises) { exercise in
                    exerciseRow(exercise)
                }
            }
        }
        .frame(maxHeight: verticalSizeClass == .compact ? 150 : 286)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 11) {
            Image(systemName: exercise.equipment.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 34, height: 34)
                .background(Theme.cobalt.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.nameZH)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                onRemove(exercise)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(Theme.ink.opacity(0.035), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除 \(exercise.nameZH)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.stroke.opacity(0.7))
                .frame(height: 1)
                .padding(.leading, 59)
        }
    }

    private var actionSection: some View {
        actionButton(
            title: "制作训练计划",
            subtitle: "先排顺序和负荷，再开始训练",
            icon: "bolt.fill",
            disabled: exercises.isEmpty,
            action: onMakePlan
        )
        .padding(14)
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 34, height: 34)
                    .background(Theme.onAccent.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppType.callout.weight(.bold))
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(2)
                        .opacity(0.70)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(AppType.caption.weight(.bold))
                    .opacity(0.55)
            }
            .foregroundStyle(Theme.onAccent)
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Theme.cobalt)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.46 : 1)
    }
}
