import SwiftUI

/// 器械目录详情：图片、训练部位、不同部位使用方法、可练动作。
struct EquipmentCatalogDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let info: EquipmentTypeInfo
    let mode: EquipmentBrowserMode
    var onClose: (() -> Void)? = nil

    @State private var imageIndex = 0
    @State private var selectedMuscle: String?
    @State private var selectedExercise: Exercise?

    private var guide: EquipmentGuide? {
        EquipmentGuideCatalog.guide(for: info.slug)
    }

    private var isAdded: Bool {
        store.equipmentLibrary.contains { $0.equipmentType == info.slug }
    }

    private var bodyParts: [String] {
        var values: [String] = [info.bodyPartLabel]
        for part in info.secondaryBodyPartList where !values.contains(part) {
            values.append(part)
        }
        return values
    }

    private var exercises: [Exercise] {
        Array(info.planEligibleExercises.prefix(6))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                titleBlock
                bodyPartSection
                usageSection
                exercisesSection
                actionButton
            }
            .padding(20)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle(info.nameZH)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedExercise) { exercise in
            EquipmentItemDetailView(exercise: exercise)
        }
        .onAppear {
            if selectedMuscle == nil {
                selectedMuscle = info.targetMuscleList.first
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        Group {
            if info.imageURLList.isEmpty {
                EquipmentTypeImageView(info: info, symbolSize: 54)
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .background(Theme.ink.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                TabView(selection: $imageIndex) {
                    ForEach(info.imageURLList.indices, id: \.self) { index in
                        EquipmentTypeImageView(info: info, index: index, symbolSize: 54)
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(
                    .page(indexDisplayMode: info.imageURLList.count > 1 ? .automatic : .never)
                )
                .frame(height: 240)
                .background(Theme.ink.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(info.categoryLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.cobalt.opacity(0.10), in: Capsule())

                if isAdded {
                    Label("已添加", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.cobalt)
                }
            }

            Text(info.nameZH)
                .font(AppType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let nameEN = info.nameEN, !nameEN.isEmpty {
                Text(nameEN)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    // MARK: - Body parts

    private var bodyPartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("训练部位", subtitle: info.targetSummary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(bodyParts, id: \.self) { part in
                        Text(part)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Theme.cobalt)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Theme.cobalt.opacity(0.09), in: Capsule())
                    }
                }
            }
        }
        .card(padding: 14)
    }

    // MARK: - Usage

    @ViewBuilder
    private var usageSection: some View {
        if let guide {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("不同部位的使用方法", subtitle: nil)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(info.targetMuscleList, id: \.self) { muscle in
                            muscleChip(muscle)
                        }
                    }
                }

                usageBlock(title: "器械调节", text: guide.setup)

                VStack(alignment: .leading, spacing: 6) {
                    Text("动作步骤")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 7) {
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.cobalt)
                                .frame(width: 17, height: 17)
                                .background(Theme.cobalt.opacity(0.10), in: Circle())
                            Text(step)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if let muscle = selectedMuscle,
                   let cue = guide.cues[muscle],
                   !cue.isEmpty {
                    usageBlock(title: "\(muscle) 发力提示", text: cue, accent: true)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("安全提示")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondaryText)
                    ForEach(guide.safety, id: \.self) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(Theme.coral)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(item)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .card(padding: 14)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("使用方法", subtitle: nil)
                Text("这台器械的使用说明还在补充中。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .card(padding: 14)
        }
    }

    private func usageBlock(title: String, text: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent ? Theme.cobalt : Theme.secondaryText)
            Text(text)
                .font(AppType.caption)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            accent ? Theme.cobalt.opacity(0.07) : Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }

    private func muscleChip(_ muscle: String) -> some View {
        let active = selectedMuscle == muscle

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedMuscle = muscle
            }
        } label: {
            Text(muscle)
                .font(.system(size: 10.5, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Theme.onPrimary : Theme.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    active ? Theme.primary : Theme.paper,
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(active ? Theme.ink.opacity(0.10) : Theme.stroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("可练动作", subtitle: "\(exercises.count) 个")

            if exercises.isEmpty {
                Text("动作库暂未收录这台器械的动作，可在添加后手动关联。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            HStack(spacing: 9) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.nameZH)
                                        .font(AppType.callout.weight(.semibold))
                                        .foregroundStyle(Theme.ink)
                                        .lineLimit(2)
                                    Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < exercises.count - 1 {
                            Rectangle()
                                .fill(Theme.stroke.opacity(0.7))
                                .frame(height: 1)
                                .padding(.leading, 12)
                        }
                    }
                }
                .background(
                    Theme.paper,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
            }
        }
        .card(padding: 14)
    }

    // MARK: - CTA

    @ViewBuilder
    private var actionButton: some View {
        switch mode {
        case .selectType(let onSelect):
            Button {
                Haptics.tap()
                onSelect(info)
                if let onClose {
                    onClose()
                } else {
                    dismiss()
                }
            } label: {
                Label("选用这个器械", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

        case .addToLibrary:
            if isAdded {
                Label("已在我的器械库", systemImage: "checkmark.circle.fill")
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Theme.cobalt.opacity(0.09),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            } else {
                Button {
                    addToLibrary()
                } label: {
                    Label("添加到我的器械库", systemImage: "plus.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func addToLibrary() {
        let enabled = info.planEligibleExercises.map(\.slug)
        _ = store.addEquipment(
            equipmentType: info.slug,
            name: info.nameZH,
            category: info.category,
            enabledExerciseSlugs: enabled,
            source: "catalog"
        )
        Haptics.tap()
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, subtitle: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
