import SwiftUI

/// 自定义器械必选的训练细分部位：按一级部位分组多选，至少 1 个。
struct EquipmentBodyPartPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: ([String]) -> Void

    @State private var selected: Set<String>

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    init(initial: [String], onSave: @escaping ([String]) -> Void) {
        _selected = State(initialValue: Set(initial))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("选择这块器械主要练哪些细分部位，至少选 1 个。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(ExerciseLibrary.categoryTree.filter { !$0.l2.isEmpty }) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(entry.l1)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                if entry.l2.contains(where: { selected.contains($0) }) {
                                    Text("已选")
                                        .font(.system(size: 8.5, weight: .bold))
                                        .foregroundStyle(Theme.cobalt)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Theme.cobalt.opacity(0.10), in: Capsule())
                                }
                                Spacer()
                            }

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(entry.l2, id: \.self) { muscle in
                                    chip(muscle)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("训练部位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave(orderedSelection)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var orderedSelection: [String] {
        ExerciseLibrary.categoryTree
            .flatMap(\.l2)
            .filter { selected.contains($0) }
    }

    private func chip(_ muscle: String) -> some View {
        let isOn = selected.contains(muscle)

        return Button {
            Haptics.select()
            if isOn {
                selected.remove(muscle)
            } else {
                selected.insert(muscle)
            }
        } label: {
            Text(muscle)
                .font(.system(size: 11, weight: isOn ? .bold : .medium))
                .foregroundStyle(isOn ? Theme.onPrimary : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isOn ? Theme.primary : Theme.paper,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            isOn ? Theme.ink.opacity(0.12) : Theme.stroke,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(muscle)训练部位")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
