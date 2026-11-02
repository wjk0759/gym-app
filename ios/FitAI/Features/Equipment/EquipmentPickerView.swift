import SwiftUI
import UIKit

/// 器械 Tab 的动作选择器：按肌群和器械筛选，选中的动作可以生成自选训练或加入器械库。
struct EquipmentPickerView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    private let onSelectExercise: ((Exercise) -> Void)?
    private let allowedEquipment: Set<Equipment>?

    @State var selectedExercises: [Exercise] = []
    @State var selectedMuscle: MuscleGroup?
    @State var selectedEquipment: Equipment?
    @State var savedOnly = false
    @State var query = ""
    @State var showScanner = false
    @State var showSelectionPanel = false
    @State var showSelectionButton = false
    @State var feedback: String?
    @State var customDay: PlanDay?
    @State var detailExercise: Exercise?
    @State var composePayload: ComposePayload?
    @State var pendingComposeDay: PlanDay?

    struct ComposePayload: Identifiable {
        let id = UUID()
        let exercises: [PlanExercise]
    }

    init() {
        self.onSelectExercise = nil
        self.allowedEquipment = nil
    }

    init(onSelect: @escaping (Exercise) -> Void, allowedEquipment: Set<Equipment>? = nil) {
        self.onSelectExercise = onSelect
        self.allowedEquipment = allowedEquipment
    }

    var isPickingForSession: Bool {
        onSelectExercise != nil
    }

    let gridColumns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    let muscleOrder: [MuscleGroup] = [
        .chest, .back, .legs, .glutes, .shoulders, .arms, .core, .cardio
    ]

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 每次筛选只构建一次 Set，避免在 filter/sort 里反复线性查库。
    var savedSlugs: Set<String> {
        Set(store.equipmentLibrary.compactMap(\.slug))
    }

    var filteredExercises: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !text.isEmpty
        let saved = savedSlugs

        return ExerciseLibrary.all
            .filter { exercise in
                if let allowedEquipment, !allowedEquipment.contains(exercise.equipment) {
                    return false
                }
                // 一旦输入搜索词，就搜索全部动作，不再受当前肌群 / 器械分类限制。
                if isSearching {
                    return exercise.nameZH.localizedCaseInsensitiveContains(text)
                        || exercise.nameEN.localizedCaseInsensitiveContains(text)
                        || exercise.muscle.label.localizedCaseInsensitiveContains(text)
                        || exercise.equipment.label.localizedCaseInsensitiveContains(text)
                }

                let muscleMatch = selectedMuscle == nil || exercise.muscle == selectedMuscle
                let equipmentMatch = selectedEquipment == nil || exercise.equipment == selectedEquipment
                let savedMatch = !savedOnly || saved.contains(exercise.slug)
                return muscleMatch && equipmentMatch && savedMatch
            }
            .sorted { left, right in
                let leftSaved = saved.contains(left.slug)
                let rightSaved = saved.contains(right.slug)
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
        .navigationTitle(isPickingForSession ? "添加动作" : "动作库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPickingForSession {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EquipmentLibraryView()
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .accessibilityLabel("器械库")
                }
            }
        }
        .keyboardDoneToolbar()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showSelectionButton && !isPickingForSession {
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
            item: $composePayload,
            onDismiss: presentPendingComposeDay
        ) { payload in
            CustomWorkoutBuilderView(initialExercises: payload.exercises) { day in
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
    @ViewBuilder
    private var exerciseGrid: some View {
        if filteredExercises.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("没有匹配的动作")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("换个肌群或器械筛选，或者清空搜索关键词。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .padding(.top, 8)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 9) {
                ForEach(filteredExercises) { exercise in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            if let onSelectExercise {
                                onSelectExercise(exercise)
                                dismiss()
                            } else {
                                detailExercise = exercise
                            }
                        } label: {
                            EquipmentPickerExerciseCard(
                                exercise: exercise,
                                selected: selectedExercises.contains(where: { $0.slug == exercise.slug }),
                                isPickingForSession: isPickingForSession
                            )
                        }
                        .buttonStyle(CardPressStyle(scale: 0.985))
                        .accessibilityLabel(isPickingForSession ? "添加\(exercise.nameZH)" : "查看\(exercise.nameZH)详情")

                        if !isPickingForSession {
                            Button {
                                toggle(exercise)
                            } label: {
                                EquipmentPickerSelectionControl(
                                    exercise: exercise,
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

    private func toggle(_ exercise: Exercise) {
        Haptics.select()
        withAnimation(Motion.quick) {
            if selectedExercises.contains(where: { $0.slug == exercise.slug }) {
                selectedExercises.removeAll { $0.slug == exercise.slug }
            } else {
                selectedExercises.append(exercise)
            }
        }
    }

    func makeTrainingPlanFromSelection() {
        guard !selectedExercises.isEmpty else { return }
        Haptics.tap()
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
        let payload = ComposePayload(exercises: exercises)

        // 等气泡收起后再打开编排页，避免两个 presentation 争抢。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            composePayload = payload
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

    func addSelectedToLibrary() {
        guard !selectedExercises.isEmpty else { return }
        let added = store.addExercisesToEquipmentLibrary(selectedExercises)
        if added > 0 {
            Haptics.success()
        } else {
            Haptics.warning()
        }
        selectedExercises.removeAll()
        showSelectionPanel = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            feedback = added > 0 ? "已加入器械库 \(added) 个动作" : "这些动作已经在器械库"
        }
    }

}
