import Foundation
import SwiftUI
import UIKit

enum CustomWorkoutMode: Equatable {
    case plan
    case custom
    case editPlan
}

/// 训练编排页。今日计划、自选训练和计划训练日共用同一套排序、组数、次数和重量编辑。
struct CustomWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let initialExercises: [PlanExercise]
    let onStart: (PlanDay) -> Void
    let onSave: ((PlanDay) -> Void)?
    let templateDay: PlanDay?
    let mode: CustomWorkoutMode
    let title: String

    @State private var exercises: [PlanExercise]
    @State private var showActionPicker = false

    init(
        title: String? = nil,
        mode: CustomWorkoutMode = .custom,
        initialExercises: [PlanExercise],
        templateDay: PlanDay? = nil,
        onStart: @escaping (PlanDay) -> Void
    ) {
        self.initialExercises = initialExercises
        self.onStart = onStart
        self.onSave = nil
        self.templateDay = templateDay
        self.mode = mode
        self.title = title ?? (mode == .plan ? "今日训练" : "自选训练")
        _exercises = State(initialValue: initialExercises.map { item in
            var item = item
            item.reps = WorkoutPickerOptions.normalizedReps(item.reps)
            return item
        })
    }

    init(editing day: PlanDay, onSave: @escaping (PlanDay) -> Void) {
        self.initialExercises = day.exercises
        self.onStart = { _ in }
        self.onSave = onSave
        self.templateDay = day
        self.mode = .editPlan
        self.title = day.title
        _exercises = State(initialValue: day.exercises.map { item in
            var item = item
            item.reps = WorkoutPickerOptions.normalizedReps(item.reps)
            return item
        })
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + max(1, $1.sets) }
    }

    private var estimatedMinutes: Int {
        let work = exercises.reduce(0.0) { partial, item in
            partial + Double(max(1, item.sets)) * Double(max(1, item.restSec)) / 60 + 3
        }
        return max(15, Int(work.rounded()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                AppScrollView {
                    VStack(spacing: AppLayout.sectionSpacing) {
                        summaryCard

                        HStack {
                            Text("训练顺序")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.primaryText)
                            Spacer(minLength: 8)
                            Text("按住左侧手柄拖动排序")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.horizontal, 2)

                        if exercises.isEmpty {
                            EmptyStateView(
                                icon: "dumbbell",
                                title: "还没有动作",
                                message: "返回动作库重新选择。"
                            )
                        } else {
                            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, _ in
                                exerciseEditor(index: index)
                                    .id(exercises[index].id)
                            }
                        }

                        if mode == .editPlan {
                            Button {
                                showActionPicker = true
                            } label: {
                                Label("从动作库添加动作", systemImage: "plus")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .appPagePadding()
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                    .appReadableContent()
                }
                .onChange(of: exercises.count) { oldCount, newCount in
                    guard newCount > oldCount, let last = exercises.last else { return }
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo(last.id, anchor: .center)
                    }
                }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
            .background(AppBackground())
            .onAppear {
                // @State 首次初始化偶发早于 presentation 的新数据；此时用入参兜底，避免空白页。
                guard exercises.isEmpty, !initialExercises.isEmpty else { return }
                exercises = initialExercises.map { item in
                    var item = item
                    item.reps = WorkoutPickerOptions.normalizedReps(item.reps)
                    return item
                }
            }
            .navigationTitle(mode == .editPlan ? "编辑训练日" : "安排训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
            .sheet(isPresented: $showActionPicker) {
                NavigationStack {
                    EquipmentPickerView(
                        onSelect: { exercise in
                            addExercise(exercise)
                        },
                        allowedEquipment: store.profile.availableEquipment
                    )
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .plan ? "今日训练" : mode == .editPlan ? "训练日" : "自选训练")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(mode == .plan || mode == .editPlan ? title : "先排顺序，再开始")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.primaryText)
            Text(mode == .editPlan
                 ? "调整动作顺序、组数和负荷；保存后直接写回训练计划。"
                 : mode == .plan
                 ? "今天的动作顺序、组数和重量都可以先调整；开始后仍可随时修改本次目标。"
                 : "动作顺序、组数、次数、重量都可以先改；开始后仍可在训练页临时调整。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                stat("\(exercises.count)", "个动作")
                stat("\(totalSets)", "组")
                stat("约 \(estimatedMinutes)", "分钟")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func metaText(_ info: Exercise?) -> String {
        guard let info else { return "" }
        return "\(info.muscle.label) · \(info.equipment.label)"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
        }
        .motionAnimation(Motion.quick, value: value)
    }

    private func exerciseEditor(index: Int) -> some View {
        let item = exercises[index]
        let info = item.exercise

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 24, height: 36)
                    .contentShape(Rectangle())
                    .draggable(item.id.uuidString)
                    .accessibilityLabel("拖动排序")

                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.accent.opacity(0.16), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(info?.nameZH ?? item.slug)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                    Text(metaText(info))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    iconButton("trash", label: "移除", destructive: true) {
                        remove(index)
                    }
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7)
            ], spacing: 8) {
                WheelPickerField(
                    title: "组数 · 组",
                    selection: $exercises[index].sets,
                    options: WorkoutPickerOptions.sets,
                    display: { "\($0)" }
                )
                WheelPickerField(
                    title: "每组次数 · 次",
                    selection: $exercises[index].reps,
                    options: WorkoutPickerOptions.reps,
                    display: { $0 }
                )
                WeightInputField(
                    title: "目标重量",
                    weight: weightBinding(index)
                )
                WheelPickerField(
                    title: "组间休息 · 秒",
                    selection: $exercises[index].restSec,
                    options: WorkoutPickerOptions.rests(including: exercises[index].restSec),
                    display: { "\($0)" }
                )
            }
        }
        .padding(11)
        .background {
            SoftSurface(
                cornerRadius: 17,
                tint: Theme.surface,
                stroke: Theme.stroke
            )
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let raw = items.first,
                let id = UUID(uuidString: raw),
                let source = exercises.firstIndex(where: { $0.id == id }),
                source != index
            else { return false }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                let moved = exercises.remove(at: source)
                exercises.insert(moved, at: min(index, exercises.count))
            }
            Haptics.select()
            return true
        }
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destructive ? Theme.danger : Theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    SoftSurface(
                        cornerRadius: 10,
                        tint: Theme.surface,
                        stroke: Theme.stroke
                    )
                }
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .disabled(disabled)
        .opacity(disabled ? 0.26 : 1)
        .accessibilityLabel(label)
    }

    private func weightBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { exercises[index].weightKG ?? 0 },
            set: { weight in
                exercises[index].weightKG = weight > 0 ? weight : nil
            }
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(totalSets) 组 · 约 \(estimatedMinutes) 分钟")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
                Text(mode == .editPlan ? "保存后立即更新计划" : "开始后仍可调整")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Button(mode == .editPlan ? "保存训练日" : "开始本次训练") {
                if mode == .editPlan {
                    save()
                } else {
                    start()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(exercises.isEmpty)
            .opacity(exercises.isEmpty ? 0.45 : 1)
        }
        .appPagePadding()
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }

    private func remove(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        withAnimation(Motion.quick) {
            exercises.remove(at: index)
        }
        Haptics.select()
    }

    private var normalizedExercises: [PlanExercise] {
        exercises.map { item in
            var item = item
            item.sets = min(max(item.sets, 1), 10)
            item.reps = WorkoutPickerOptions.normalizedReps(item.reps)
            item.restSec = min(max(item.restSec, 0), 300)
            item.weightKG = (item.weightKG ?? 0) > 0 ? item.weightKG : nil
            return item
        }
    }

    private func addExercise(_ exercise: Exercise) {
        guard !exercises.contains(where: { $0.slug == exercise.slug }) else { return }
        let previous = exercises.last
        let item = PlanExercise(
            slug: exercise.slug,
            sets: previous?.sets ?? 3,
            reps: previous?.reps ?? "10",
            weightKG: nil,
            restSec: previous?.restSec ?? 60,
            rpe: previous?.rpe ?? 7.5
        )
        Haptics.select()
        withAnimation(Motion.quick) {
            exercises.append(item)
        }
    }

    private func start() {
        guard !exercises.isEmpty else { return }
        let normalized = normalizedExercises
        let focus = Array(Set(normalized.compactMap { $0.exercise?.muscle }))
        onStart(
            PlanDay(
                id: templateDay?.id ?? UUID(),
                weekIndex: templateDay?.weekIndex ?? 1,
                weekday: templateDay?.weekday ?? Weekday.today,
                date: templateDay?.date ?? Date(),
                title: templateDay?.title ?? title,
                focus: focus,
                exercises: normalized
            )
        )
        dismiss()
    }

    private func save() {
        guard !exercises.isEmpty, let onSave else { return }
        let normalized = normalizedExercises
        let focus = Array(Set(normalized.compactMap { $0.exercise?.muscle }))
        onSave(
            PlanDay(
                id: templateDay?.id ?? UUID(),
                weekIndex: templateDay?.weekIndex ?? 1,
                weekday: templateDay?.weekday ?? Weekday.today,
                date: templateDay?.date,
                title: templateDay?.title ?? title,
                focus: focus,
                exercises: normalized
            )
        )
        dismiss()
    }
}
