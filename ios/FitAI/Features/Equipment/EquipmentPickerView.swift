import SwiftUI
import UIKit

/// 器械 Tab 的动作选择器：按肌群和器械筛选，选中的动作可以组合成一次训练。
struct EquipmentPickerView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedExercises: [Exercise] = []
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var savedOnly = false
    @State private var query = ""
    @State private var showScanner = false
    @State private var customDay: PlanDay?

    init() {}

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let muscleOrder: [MuscleGroup] = [
        .chest, .back, .legs, .glutes, .shoulders, .arms, .core, .cardio
    ]

    private var filteredExercises: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return ExerciseLibrary.all
            .filter { exercise in
                let queryMatch = text.isEmpty
                    || exercise.nameZH.localizedCaseInsensitiveContains(text)
                    || exercise.nameEN.localizedCaseInsensitiveContains(text)
                    || exercise.muscle.label.contains(text)
                    || exercise.equipment.label.contains(text)
                let muscleMatch = selectedMuscle == nil || exercise.muscle == selectedMuscle
                let equipmentMatch = selectedEquipment == nil || exercise.equipment == selectedEquipment
                let savedMatch = !savedOnly || store.equipmentLibrary.contains { $0.slug == exercise.slug }
                return queryMatch && muscleMatch && equipmentMatch && savedMatch
            }
            .sorted { left, right in
                let leftSaved = store.equipmentLibrary.contains { $0.slug == left.slug }
                let rightSaved = store.equipmentLibrary.contains { $0.slug == right.slug }
                if leftSaved != rightSaved {
                    return leftSaved
                }
                return left.nameZH < right.nameZH
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                selectedSection
                searchBar

                HStack(alignment: .top, spacing: 10) {
                    muscleRail

                    VStack(alignment: .leading, spacing: 12) {
                        equipmentFilters
                        exerciseGrid
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 94)
        }
        .background(AppBackground())
        .navigationTitle("选择动作")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EquipmentLibraryView()
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("器械库")
            }
        }
        .navigationDestination(isPresented: $showScanner) {
            EquipmentRecognitionView { exercise in
                if !selectedExercises.contains(where: { $0.slug == exercise.slug }) {
                    selectedExercises.append(exercise)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .fullScreenCover(item: $customDay) { day in
            WorkoutSessionView(day: day)
        }
    }

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已选择动作")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(selectedExercises.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if !selectedExercises.isEmpty {
                    Button("清空") {
                        selectedExercises.removeAll()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
                }
            }

            if selectedExercises.isEmpty {
                Text("从下面选择动作，组合成一次训练。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedExercises) { exercise in
                            selectedChip(exercise)
                        }
                    }
                }
            }
        }
    }

    private func selectedChip(_ exercise: Exercise) -> some View {
        HStack(spacing: 7) {
            Image(systemName: exercise.equipment.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 26, height: 26)
                .background(Theme.accent.opacity(0.12), in: Circle())

            Text(exercise.nameZH)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Button {
                selectedExercises.removeAll { $0.slug == exercise.slug }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除 \(exercise.nameZH)")
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(Theme.surfaceStrong, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            TextField("输入动作名字搜索", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .submitLabel(.search)

            Button {
                showScanner = true
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("识别器械")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(Theme.surfaceStrong, in: Capsule())
    }

    private var muscleRail: some View {
        VStack(alignment: .leading, spacing: 3) {
            muscleButton(nil, title: "全部")
            ForEach(muscleOrder) { muscle in
                muscleButton(muscle, title: muscle.label)
            }
        }
        .frame(width: 62, alignment: .leading)
    }

    private func muscleButton(_ muscle: MuscleGroup?, title: String) -> some View {
        Button {
            selectedMuscle = muscle
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(selectedMuscle == muscle ? Theme.accent : Color.clear)
                    .frame(width: 3, height: 20)
                Text(title)
                    .font(.subheadline.weight(selectedMuscle == muscle ? .semibold : .regular))
                    .foregroundStyle(selectedMuscle == muscle ? Theme.accent : Theme.secondaryText)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var equipmentFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("全部", selected: selectedEquipment == nil && !savedOnly) {
                    selectedEquipment = nil
                    savedOnly = false
                }
                filterChip("已添加", selected: savedOnly && selectedEquipment == nil) {
                    savedOnly = true
                    selectedEquipment = nil
                }
                ForEach(Equipment.allCases) { equipment in
                    filterChip(
                        equipment.label,
                        selected: selectedEquipment == equipment && !savedOnly
                    ) {
                        selectedEquipment = equipment
                        savedOnly = false
                    }
                }
            }
        }
    }

    private func filterChip(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.black : Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selected ? Theme.accent : Theme.accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var exerciseGrid: some View {
        if filteredExercises.isEmpty {
            EmptyStateView(
                icon: "line.3.horizontal.decrease.circle",
                title: "没有匹配的动作",
                message: "换个肌群或器械筛选，或者清空搜索关键词。"
            )
            .padding(.top, 8)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(filteredExercises) { exercise in
                    Button {
                        toggle(exercise)
                    } label: {
                        exerciseCard(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        let selected = selectedExercises.contains(where: { $0.slug == exercise.slug })

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surfaceStrong, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 112)

                Image(systemName: exercise.equipment.symbolName)
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.accent.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if exercise.videoURL != nil {
                    Text("讲解")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: Capsule())
                        .padding(7)
                }

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .background(.black, in: Circle())
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }

            Text(exercise.nameZH)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.top, 9)

            Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.top, 3)
                .padding(.bottom, 10)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Theme.accent.opacity(0.7) : Theme.stroke, lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                selectedExercises.removeAll()
            } label: {
                Text("清空")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(selectedExercises.isEmpty)
            .opacity(selectedExercises.isEmpty ? 0.45 : 1)

            Button {
                startCombination()
            } label: {
                Text(selectedExercises.isEmpty ? "选择动作" : "组合 \(selectedExercises.count) 个动作")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedExercises.isEmpty)
            .opacity(selectedExercises.isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedExercises.contains(where: { $0.slug == exercise.slug }) {
            selectedExercises.removeAll { $0.slug == exercise.slug }
        } else {
            selectedExercises.append(exercise)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func startCombination() {
        guard !selectedExercises.isEmpty else { return }
        let exercises = selectedExercises.map { exercise in
            PlanExercise(
                slug: exercise.slug,
                sets: 3,
                reps: "10-12",
                weightKG: nil,
                restSec: 60,
                rpe: 7.5
            )
        }
        let focus = Array(Set(selectedExercises.map(\.muscle)))
        customDay = PlanDay(
            weekday: Weekday.today,
            title: "组合训练",
            focus: focus,
            exercises: exercises
        )
    }
}
