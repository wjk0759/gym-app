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
    @State private var showCompose = false
    @State private var composeExercises: [PlanExercise] = []
    @State private var pendingComposeDay: PlanDay?

    init() {}

    private let gridColumns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    private let muscleOrder: [MuscleGroup] = [
        .chest, .back, .legs, .glutes, .shoulders, .arms, .core, .cardio
    ]

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

            libraryHeader

            HStack(alignment: .top, spacing: 9) {
                muscleSidebar

                AppScrollView {
                    exerciseGrid
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                        .padding(.bottom, 28)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(AppBackground())
        .navigationTitle("动作库")
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
        .fullScreenCover(
            isPresented: $showCompose,
            onDismiss: presentPendingComposeDay
        ) {
            CustomWorkoutBuilderView(initialExercises: composeExercises) { day in
                pendingComposeDay = day
            }
        }
        .fullScreenCover(item: $customDay) { day in
            WorkoutSessionView(day: day)
        }
        .sheet(item: $detailExercise) { exercise in
            EquipmentItemDetailView(exercise: exercise)
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
        VStack(alignment: .leading, spacing: 9) {
            searchBar

            if isSearching {
                searchScopeHint
            }

            equipmentFilters
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 12)
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

    private var libraryHeader: some View {
        HStack(spacing: 6) {
            Text("动作库")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)

            Text("\(filteredExercises.count)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.accent.opacity(0.08), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Theme.accent.opacity(0.14), lineWidth: 1)
                )

            Spacer(minLength: 8)

            Text("点卡片看详情 · ⊕ 多选")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var searchScopeHint: some View {
        Label("全库搜索中，点分类可退出搜索", systemImage: "magnifyingglass")
            .font(.system(size: 10.5))
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.tertiaryText.opacity(0.82))

            TextField("搜索动作、肌群或器械", text: $query)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清空搜索")
            }

            Button {
                showScanner = true
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Theme.accent.opacity(0.13),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Theme.accent.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("拍照识别器械")
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 6)
        .frame(minHeight: 48)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.065), Color.white.opacity(0.032)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .background(
            Theme.surfaceStrong.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private var muscleSidebar: some View {
        VStack(spacing: 1) {
            muscleSideButton(nil, title: "全部")
            ForEach(muscleOrder) { muscle in
                muscleSideButton(muscle, title: muscle.label)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(width: 56)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.028), Color.white.opacity(0.012)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .background(
            Theme.surface.opacity(0.86),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func muscleSideButton(_ muscle: MuscleGroup?, title: String) -> some View {
        let active = selectedMuscle == muscle && !isSearching

        return Button {
            selectedMuscle = muscle
            if isSearching {
                query = ""
            }
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Theme.accent : Theme.secondaryText.opacity(0.86))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6.5)
                .background(
                    active ? Theme.accent.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(
                            active ? Theme.accent.opacity(0.12) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)肌群")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var equipmentFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip("全部", selected: selectedEquipment == nil && !savedOnly && !isSearching) {
                    selectedEquipment = nil
                    savedOnly = false
                    query = ""
                }
                filterChip("已添加", selected: savedOnly && selectedEquipment == nil && !isSearching) {
                    savedOnly = true
                    selectedEquipment = nil
                    query = ""
                }
                ForEach(Equipment.allCases) { equipment in
                    filterChip(
                        equipment.label,
                        selected: selectedEquipment == equipment && !savedOnly && !isSearching
                    ) {
                        selectedEquipment = equipment
                        savedOnly = false
                        query = ""
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Theme.accent : Theme.secondaryText.opacity(0.86))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selected ? Theme.accent.opacity(0.14) : Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            selected ? Theme.accent.opacity(0.36) : Theme.stroke,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            LazyVGrid(columns: gridColumns, spacing: 9) {
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

    private func exerciseCard(_ exercise: Exercise) -> some View {
        let selected = selectedExercises.contains(where: { $0.slug == exercise.slug })

        return VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.17, green: 0.20, blue: 0.19), Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [Theme.accent.opacity(0.10), .clear],
                            center: .top,
                            startRadius: 2,
                            endRadius: 72
                        )
                    )
                    .frame(height: 102)

                Circle()
                    .fill(Theme.accent.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Theme.accent.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: muscleSymbol(exercise.muscle))
                            .font(.system(size: 29, weight: .light))
                            .foregroundStyle(Theme.accent.opacity(0.9))
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
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 9)
                .padding(.top, 9)

            HStack(spacing: 3) {
                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryText.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText.opacity(0.72))
            }
            .padding(.horizontal, 9)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .background(selected ? Theme.accent.opacity(0.055) : Color.clear)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.018)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    selected ? Theme.accent.opacity(0.62) : Color.white.opacity(0.075),
                    lineWidth: 1
                )
        )
        .shadow(
            color: selected ? Theme.accent.opacity(0.12) : .black.opacity(0.12),
            radius: 10,
            y: 6
        )
    }

    private func muscleSymbol(_ muscle: MuscleGroup) -> String {
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
        showSelectionPanel = false
        pendingComposeDay = nil

        // 等气泡收起后再打开编排页，避免两个 presentation 争抢。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            composeExercises = exercises
            showCompose = true
        }
    }

    private func presentPendingComposeDay() {
        guard let day = pendingComposeDay else { return }
        pendingComposeDay = nil
        selectedExercises.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            customDay = day
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

}
