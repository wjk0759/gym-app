import SwiftUI

struct PlanEditorView: View {
    @Environment(AppStore.self) private var store

    let day: PlanDay

    var body: some View {
        CustomWorkoutBuilderView(editing: day) { updated in
            store.updateDay(updated)
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let equipment: Set<Equipment>
    let onSelect: (Exercise) -> Void

    @State private var query = ""
    @State private var selectedMuscle: MuscleGroup?

    private var results: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = ExerciseLibrary.candidates(
            muscle: selectedMuscle,
            equipment: equipment
        )
        guard !text.isEmpty else {
            return candidates
        }
        return candidates.filter { exercise in
            exercise.nameZH.localizedCaseInsensitiveContains(text)
                || exercise.nameEN.localizedCaseInsensitiveContains(text)
                || exercise.muscle.label.localizedCaseInsensitiveContains(text)
                || exercise.equipment.label.localizedCaseInsensitiveContains(text)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: "全部", selected: selectedMuscle == nil) {
                            selectedMuscle = nil
                        }
                        ForEach(MuscleGroup.allCases) { muscle in
                            filterChip(
                                title: muscle.label,
                                selected: selectedMuscle == muscle
                            ) {
                                selectedMuscle = muscle
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                List {
                    ForEach(results) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.nameZH)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Theme.accent)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Theme.background)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .searchable(text: $query, prompt: "搜索动作")
            }
            .background(AppBackground())
            .navigationTitle("选择动作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func filterChip(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            TagChip(text: title, selected: selected)
        }
        .buttonStyle(.plain)
    }
}
