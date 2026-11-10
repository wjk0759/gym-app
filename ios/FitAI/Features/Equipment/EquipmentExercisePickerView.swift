import SwiftUI

/// 给自定义器械关联动作：多选后写入这件器械的 enabledExerciseSlugs。
struct EquipmentExercisePickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let equipmentID: UUID

    @State private var selected: Set<String> = []
    @State private var query = ""
    @State private var loaded = false

    private var candidates: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ExerciseLibrary.planEligible
            .filter { text.isEmpty || $0.searchKey.contains(text) }
            .sorted { $0.nameZH < $1.nameZH }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    searchBar

                    Text("已选 \(selected.count) 个动作 · 只列可进计划的力量动作")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)

                    LazyVStack(spacing: 0) {
                        ForEach(Array(candidates.enumerated()), id: \.element.id) { index, exercise in
                            row(exercise)
                            if index < candidates.count - 1 {
                                Rectangle()
                                    .fill(Theme.stroke.opacity(0.7))
                                    .frame(height: 1)
                                    .padding(.leading, 14)
                            }
                        }
                    }
                    .background(
                        Theme.paper,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("添加动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.replaceEquipmentExercises(
                            equipmentID,
                            slugs: Array(selected)
                        )
                        dismiss()
                    }
                }
            }
            .keyboardDoneToolbar()
            .onAppear {
                guard !loaded else { return }
                loaded = true
                let item = store.equipmentLibrary.first { $0.id == equipmentID }
                selected = Set(item?.enabledExerciseSlugs ?? [])
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            TextField("搜索动作", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let isOn = selected.contains(exercise.slug)

        return Button {
            Haptics.select()
            if isOn {
                selected.remove(exercise.slug)
            } else {
                selected.insert(exercise.slug)
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.nameZH)
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 6)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(isOn ? Theme.cobalt : Theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
