import SwiftUI

struct PlanEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: PlanDay
    @State private var showPicker = false

    init(day: PlanDay) {
        _draft = State(initialValue: day)
    }

    var body: some View {
        AppScrollView {
            VStack(spacing: 14) {
                header

                ForEach($draft.exercises) { $item in
                    exerciseEditor($item)
                }

                Button {
                    showPicker = true
                } label: {
                    Label("添加动作", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("换动作时只会展示你的器械可用的动作。保存后立即生效。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(AppBackground())
        .navigationTitle("编辑训练日")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    store.updateDay(draft)
                    dismiss()
                }
                .disabled(draft.exercises.isEmpty)
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(equipment: store.profile.availableEquipment) { exercise in
                draft.exercises.append(
                    PlanExercise(
                        slug: exercise.slug,
                        sets: 3,
                        reps: "10-12",
                        weightKG: nil,
                        restSec: 60,
                        rpe: 7
                    )
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Weekday.label(draft.weekday)) · 第 \(draft.weekIndex) 周")
                .font(.caption)
                .foregroundStyle(Theme.accent)
            Text(draft.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(draft.focusText)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func exerciseEditor(_ item: Binding<PlanExercise>) -> some View {
        let exercise = item.wrappedValue.exercise
        let canDelete = draft.exercises.count > 1

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.wrappedValue.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button(role: .destructive) {
                    if canDelete {
                        draft.exercises.removeAll { $0.id == item.wrappedValue.id }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.footnote)
                        .foregroundStyle(canDelete ? Theme.danger : Theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                Stepper(value: item.sets, in: 1...6) {
                    Text("\(item.wrappedValue.sets) 组")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                Stepper(value: item.restSec, in: 0...300, step: 15) {
                    Text("休息 \(item.wrappedValue.restSec)s")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            HStack {
                Text("次数")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                TextField("10-12", text: item.reps)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .padding(8)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }

            if exercise?.equipment != .bodyweight {
                HStack {
                    Text("重量")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    TextField("0", value: weightBinding(item), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .padding(8)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
        .card(padding: 14)
    }

    private func weightBinding(_ item: Binding<PlanExercise>) -> Binding<Double> {
        Binding(
            get: { item.wrappedValue.weightKG ?? 0 },
            set: { item.wrappedValue.weightKG = $0 }
        )
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let equipment: Set<Equipment>
    let onSelect: (Exercise) -> Void

    @State private var query = ""
    @State private var selectedMuscle: MuscleGroup?

    private var results: [Exercise] {
        ExerciseLibrary
            .candidates(muscle: selectedMuscle, equipment: equipment)
            .filter { exercise in
                query.isEmpty
                    || exercise.nameZH.contains(query)
                    || exercise.nameEN.localizedCaseInsensitiveContains(query)
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
