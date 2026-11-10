import SwiftUI
import UIKit

/// 物理器械详情：展示这件器械能练的动作，并维护个人动作库。
///
/// 个人动作库是扁平的：这里的「取消」= 从个人动作库移除（全局），不会删除器械。
struct PhysicalEquipmentDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let equipmentID: UUID

    @State private var selectedTrainingType: String = "力量"

    private struct ExerciseGroup: Identifiable {
        let part: String
        let exercises: [Exercise]
        var id: String { part }
    }

    private var item: EquipmentItem? {
        store.equipmentLibrary.first { $0.id == equipmentID }
    }

    private var trainable: [Exercise] {
        item?.trainableExercises ?? []
    }

    private var selectedSlugs: Set<String> {
        Set(store.personalExerciseSlugs)
    }

    private var eligibleTrainable: [Exercise] {
        trainable.filter(\.planEligible)
    }

    private var selectedEligibleCount: Int {
        eligibleTrainable.filter { selectedSlugs.contains($0.slug) }.count
    }

    private var availableTypes: [String] {
        let types = Set(trainable.map(\.trainingType))
        return ExerciseLibrary.trainingTypes.filter { types.contains($0) }
    }

    private var groupedExercises: [ExerciseGroup] {
        let items = trainable.filter { $0.trainingType == selectedTrainingType }
        let grouped = Dictionary(grouping: items) { $0.bodyPart ?? "全身" }
        let order = ExerciseLibrary.categoryTree.map(\.l1) + ["全身"]
        return order.compactMap { part in
            guard let exercises = grouped[part], !exercises.isEmpty else { return nil }
            let sorted = exercises.sorted { lhs, rhs in
                if lhs.planEligible != rhs.planEligible { return lhs.planEligible }
                return lhs.nameZH < rhs.nameZH
            }
            return ExerciseGroup(part: part, exercises: sorted)
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                if let item {
                    content(item)
                } else {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "器械不存在",
                        message: "它可能已经被删除。"
                    )
                    .padding(20)
                }
            }
            .background(AppBackground())
            .navigationTitle("器械详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func content(_ item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            hero(item)
            overview(item)

            if item.equipmentType == nil {
                customEquipmentCard
            } else if trainable.isEmpty {
                noExercisesCard
            } else {
                trainingTypeTabs
                exerciseGroups

                if !eligibleTrainable.isEmpty {
                    bulkActions
                }
            }

            if !eligibleTrainable.isEmpty {
                generatePlanButton
            }
        }
        .padding(20)
        .padding(.bottom, 28)
    }

    // MARK: - Hero

    private func hero(_ item: EquipmentItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.ink.opacity(0.035))
                if let data = item.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: symbol(for: item))
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Theme.cobalt)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("EQUIPMENT / 器械")
                    .font(AppType.overline)
                    .tracking(1.5)
                    .foregroundStyle(Theme.cobalt)

                Text(item.name)
                    .font(AppType.display)
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(categoryLabel(item))
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)

                Text(trainable.isEmpty ? "暂无关联动作" : "可练 \(trainable.count) 个动作")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 0)
        }
        .editorialCard(accent: Theme.lime)
    }

    // MARK: - Overview

    private func overview(_ item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("个人动作库")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text("力量动作 \(selectedEligibleCount) / \(eligibleTrainable.count)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 42, height: 42)
                    .background(
                        Theme.cobalt.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.06))
                    Capsule()
                        .fill(Theme.cobalt)
                        .frame(
                            width: geo.size.width * progress,
                            alignment: .leading
                        )
                }
            }
            .frame(height: 6)
        }
        .card(padding: 16)
    }

    private var progress: CGFloat {
        guard !eligibleTrainable.isEmpty else { return 0 }
        return CGFloat(selectedEligibleCount) / CGFloat(eligibleTrainable.count)
    }

    // MARK: - Training type tabs

    private var trainingTypeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(availableTypes, id: \.self) { type in
                    Button {
                        Haptics.select()
                        selectedTrainingType = type
                    } label: {
                        Text(type)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                selectedTrainingType == type ? Theme.onPrimary : Theme.secondaryText
                            )
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6.5)
                            .background(
                                selectedTrainingType == type ? Theme.primary : Theme.paper,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(
                                        selectedTrainingType == type
                                            ? Theme.ink.opacity(0.12)
                                            : Theme.stroke,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Exercise groups

    private var exerciseGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            if groupedExercises.isEmpty {
                Text("这个训练类型下没有动作")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(groupedExercises) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.part)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.leading, 2)

                        VStack(spacing: 0) {
                            ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, exercise in
                                exerciseRow(exercise)
                                if index < group.exercises.count - 1 {
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
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        let added = selectedSlugs.contains(exercise.slug)
        let eligible = exercise.planEligible

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.nameZH)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(eligible ? Theme.ink : Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 6)

            if eligible {
                Button {
                    Haptics.select()
                    toggle(exercise)
                } label: {
                    Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(added ? Theme.cobalt : Theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(added ? "从个人动作库移除\(exercise.nameZH)" : "加入个人动作库\(exercise.nameZH)")
            } else {
                Text("仅参考")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.ink.opacity(0.04), in: Capsule(style: .continuous))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - Bulk actions

    private var bulkActions: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.success()
                store.addExercisesToPersonalLibrary(
                    eligibleTrainable,
                    equipmentType: item?.equipmentType
                )
            } label: {
                Text("全部加入")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                Haptics.tap()
                store.removeExercisesFromPersonalLibrary(
                    eligibleTrainable.map(\.slug)
                )
            } label: {
                Text("全部移除")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Generate plan

    private var generatePlanButton: some View {
        Button {
            Haptics.tap()
            store.generatePlan(force: true)
        } label: {
            Label("用这件器械生成计划", systemImage: "sparkles")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    // MARK: - Empty states

    private var customEquipmentCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 50, height: 50)
                .background(
                    Theme.cobalt.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            Text("自定义器械")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("这件器械没有关联到标准器械类型。可以从动作库手动添加动作到个人动作库。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                EquipmentPickerView()
            } label: {
                Label("从动作库添加", systemImage: "plus.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }

    private var noExercisesCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 50, height: 50)
                .background(
                    Theme.cobalt.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                )
            Text("动作库暂未收录")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("这件器械的示范动作还没进入动作库。可以先用动作库里的同类动作。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }

    // MARK: - Helpers

    private func toggle(_ exercise: Exercise) {
        if selectedSlugs.contains(exercise.slug) {
            store.removeFromPersonalLibrary(exercise.slug)
        } else {
            store.addExercisesToPersonalLibrary(
                [exercise],
                equipmentType: item?.equipmentType
            )
        }
    }

    private func symbol(for item: EquipmentItem) -> String {
        switch item.category {
        case "cardio": return "figure.run"
        case "free_weight": return "dumbbell"
        case "cable": return "point.3.connected.trianglepath.dotted"
        case "accessory": return "link"
        default: return "gearshape.fill"
        }
    }

    private func categoryLabel(_ item: EquipmentItem) -> String {
        switch item.category {
        case "machine": return "固定器械"
        case "cable": return "绳索器械"
        case "free_weight": return "自由重量"
        case "cardio": return "有氧器械"
        case "accessory": return "小工具"
        default: return "器械"
        }
    }
}
