import SwiftUI
import UIKit

/// 器械 Tab 的动作选择器：按肌群和器械筛选，选中的动作可以生成自选训练或加入器械库。
struct EquipmentPickerView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedExercises: [Exercise] = []
    @State private var selectedMuscle: MuscleGroup?
    @State private var selectedEquipment: Equipment?
    @State private var savedOnly = false
    @State private var query = ""
    @State private var showScanner = false
    @State private var showSelectionPanel = false
    @State private var showSelectionButton = false
    @State private var feedback: String?
    @State private var customDay: PlanDay?
    @State private var detailExercise: Exercise?

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
        let isSearching = !text.isEmpty

        return ExerciseLibrary.all
            .filter { exercise in
                // 一旦输入搜索词，就搜索全部动作，不再受当前肌群 / 器械分类限制。
                if isSearching {
                    return exercise.nameZH.localizedCaseInsensitiveContains(text)
                        || exercise.nameEN.localizedCaseInsensitiveContains(text)
                        || exercise.muscle.label.localizedCaseInsensitiveContains(text)
                        || exercise.equipment.label.localizedCaseInsensitiveContains(text)
                }

                let muscleMatch = selectedMuscle == nil || exercise.muscle == selectedMuscle
                let equipmentMatch = selectedEquipment == nil || exercise.equipment == selectedEquipment
                let savedMatch = !savedOnly || store.equipmentLibrary.contains { $0.slug == exercise.slug }
                return muscleMatch && equipmentMatch && savedMatch
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
        VStack(spacing: 0) {
            equipmentTools

            HStack(alignment: .top, spacing: 8) {
                muscleSidebar

                AppScrollView {
                    exerciseGrid
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showSelectionButton {
                HStack {
                    selectionFloatingButton
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationDestination(isPresented: $showScanner) {
            EquipmentRecognitionView { exercise in
                if !selectedExercises.contains(where: { $0.slug == exercise.slug }) {
                    selectedExercises.append(exercise)
                }
            }
        }
        .fullScreenCover(item: $customDay) { day in
            WorkoutSessionView(day: day)
        }
        .sheet(item: $detailExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .overlay(alignment: .top) {
            feedbackBanner
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                showSelectionButton = true
            }
        }
        .onDisappear {
            showSelectionButton = false
        }
    }

    /// 搜索与器械分类固定在顶部，滚动只发生在动作列表里。
    private var equipmentTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchBar

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchScopeHint
            }

            equipmentFilters
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial,
            in: UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 20,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    private var searchScopeHint: some View {
        Label("搜索全部动作，当前分类暂不生效", systemImage: "magnifyingglass")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .padding(.leading, 4)
    }

    private var selectionFloatingButton: some View {
        Button {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            showSelectionPanel = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: selectedExercises.isEmpty ? "dumbbell" : "dumbbell.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selectedExercises.isEmpty ? Theme.tertiaryText : Theme.accent)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle().stroke(
                            selectedExercises.isEmpty ? Theme.stroke : Theme.accent.opacity(0.5),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.26), radius: 16, y: 8)

                if !selectedExercises.isEmpty {
                    Text("\(selectedExercises.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Theme.accent, in: Capsule())
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 54, height: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("已选动作，共 \(selectedExercises.count) 个")
        .popover(
            isPresented: $showSelectionPanel,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            EquipmentSelectionPanelView(
                exercises: selectedExercises,
                onRemove: { exercise in
                    selectedExercises.removeAll { $0.slug == exercise.slug }
                },
                onClear: {
                    selectedExercises.removeAll()
                },
                onMakePlan: makeTrainingPlanFromSelection,
                onAddToLibrary: addSelectedToLibrary
            )
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Theme.background)
        }
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        if let feedback {
            Text(feedback)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
                .padding(.top, 6)
                .allowsHitTesting(false)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: feedback) {
                    try? await Task.sleep(nanoseconds: 2_200_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.feedback = nil
                    }
                }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.tertiaryText)

            TextField("搜索动作名称", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .submitLabel(.search)

            Button {
                showScanner = true
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("拍照识别器械")
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 7)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private var muscleSidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            muscleSideButton(nil, title: "全部")
            ForEach(muscleOrder) { muscle in
                muscleSideButton(muscle, title: muscle.label)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .frame(width: 60, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func muscleSideButton(_ muscle: MuscleGroup?, title: String) -> some View {
        let active = selectedMuscle == muscle

        return Button {
            selectedMuscle = muscle
        } label: {
            Text(title)
                .font(.caption.weight(active ? .bold : .medium))
                .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 7)
                .background(
                    active ? Theme.accent.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
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
                .foregroundStyle(selected ? Theme.accent : Theme.secondaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    selected ? Theme.accent.opacity(0.14) : Color.white.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            selected ? Theme.accent.opacity(0.38) : Theme.stroke,
                            lineWidth: 1
                        )
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
            VStack(alignment: .leading, spacing: 7) {
                Text("点卡片看详情，右上角 ⊕ 多选")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.horizontal, 2)

                LazyVGrid(columns: gridColumns, spacing: 10) {
                    ForEach(filteredExercises) { exercise in
                        ZStack(alignment: .topTrailing) {
                            Button {
                                detailExercise = exercise
                            } label: {
                                exerciseCard(exercise)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("查看\(exercise.nameZH)详情")

                            Button {
                                toggle(exercise)
                            } label: {
                                selectionControl(
                                    exercise,
                                    selected: selectedExercises.contains(where: { $0.slug == exercise.slug })
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(7)
                        }
                    }
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
            }

            Text(exercise.nameZH)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.top, 9)

            HStack(spacing: 3) {
                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
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

    private func selectionControl(_ exercise: Exercise, selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? Theme.accent : Color.black.opacity(0.42))
            Circle()
                .stroke(selected ? Theme.accent : Color.white.opacity(0.32), lineWidth: 1)
            Image(systemName: selected ? "checkmark" : "plus")
                .font(.system(size: selected ? 11 : 10, weight: .bold))
                .foregroundStyle(selected ? Color.black : Color.white.opacity(0.82))
        }
        .frame(width: 30, height: 30)
        .contentShape(Circle())
        .accessibilityLabel(selected ? "取消选择\(exercise.nameZH)" : "选择\(exercise.nameZH)")
    }

    private func toggle(_ exercise: Exercise) {
        if selectedExercises.contains(where: { $0.slug == exercise.slug }) {
            selectedExercises.removeAll { $0.slug == exercise.slug }
        } else {
            selectedExercises.append(exercise)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func makeTrainingPlanFromSelection() {
        guard !selectedExercises.isEmpty else { return }
        let exercises = selectedExercises
        selectedExercises.removeAll()
        showSelectionPanel = false

        // 等气泡收起后再打开全屏训练，避免两个 presentation 争抢。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            startCombination(with: exercises)
        }
    }

    private func addSelectedToLibrary() {
        guard !selectedExercises.isEmpty else { return }
        let added = store.addExercisesToEquipmentLibrary(selectedExercises)
        UINotificationFeedbackGenerator().notificationOccurred(added > 0 ? .success : .warning)
        selectedExercises.removeAll()
        showSelectionPanel = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            feedback = added > 0 ? "已加入器械库 \(added) 个动作" : "这些动作已经在器械库"
        }
    }

    private func startCombination(with selected: [Exercise]) {
        guard !selected.isEmpty else { return }
        let exercises = selected.map { exercise in
            PlanExercise(
                slug: exercise.slug,
                sets: 3,
                reps: "10-12",
                weightKG: nil,
                restSec: 60,
                rpe: 7.5
            )
        }
        let focus = Array(Set(selected.map(\.muscle)))
        customDay = PlanDay(
            weekday: Weekday.today,
            title: "自选训练",
            focus: focus,
            exercises: exercises
        )
    }
}
