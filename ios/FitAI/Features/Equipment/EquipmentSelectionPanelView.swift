import SwiftUI

/// 器械页已选动作气泡：集中展示本次挑好的动作，并提供两条明确出口。
struct EquipmentSelectionPanelView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    let exercises: [Exercise]
    let onRemove: (Exercise) -> Void
    let onClear: () -> Void
    let onMakePlan: () -> Void
    let onAddToLibrary: () -> Void

    private var savedSlugs: Set<String> {
        Set(store.equipmentLibrary.compactMap(\.slug))
    }

    private var unsavedCount: Int {
        exercises.filter { !savedSlugs.contains($0.slug) }.count
    }

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
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text("已选动作")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(exercises.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
                Text(exercises.isEmpty ? "还没有选择动作" : "选好后可以直接生成训练或存入器械库")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            if !exercises.isEmpty {
                Button("清空", action: onClear)
                    .font(.caption.weight(.semibold))
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text("在下面点选动作，再决定生成训练或存入器械库。")
                .font(.caption)
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
        let saved = savedSlugs.contains(exercise.slug)

        return HStack(spacing: 11) {
            Image(systemName: exercise.equipment.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.11), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.nameZH)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)

                    if saved {
                        Text("已在库")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 4)

            Button {
                onRemove(exercise)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(Theme.surfaceStrong, in: Circle())
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
        VStack(spacing: 9) {
            actionButton(
                title: "制作训练计划",
                subtitle: "生成一次自选训练，不改动长期计划",
                icon: "bolt.fill",
                primary: true,
                disabled: exercises.isEmpty,
                action: onMakePlan
            )

            actionButton(
                title: "加入我的器械库",
                subtitle: librarySubtitle,
                icon: "archivebox.fill",
                primary: false,
                disabled: exercises.isEmpty || unsavedCount == 0,
                action: onAddToLibrary
            )
        }
        .padding(14)
    }

    private var librarySubtitle: String {
        if exercises.isEmpty {
            return "先选择动作"
        }
        if unsavedCount == 0 {
            return "所选动作都在器械库里"
        }
        return "把 \(unsavedCount) 个动作存入器械库"
    }

    private func actionButton(
        title: String,
        subtitle: String,
        icon: String,
        primary: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(primary ? Color.black.opacity(0.82) : Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        primary ? Color.black.opacity(0.12) : Theme.accent.opacity(0.11),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                    Text(subtitle)
                        .font(.caption2)
                        .lineLimit(2)
                        .opacity(0.70)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .opacity(0.55)
            }
            .foregroundStyle(primary ? Color.black.opacity(0.90) : Color.white)
            .padding(12)
            .background {
                if primary {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accentDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Theme.surfaceStrong)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(primary ? Color.white.opacity(0.18) : Theme.stroke, lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.46 : 1)
    }
}
