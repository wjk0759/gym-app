import Foundation
import SwiftUI

struct ProfileFormView: View {
    @Binding var draft: UserProfile
    var step: Int? = nil

    var body: some View {
        Group {
            if let step {
                stepContent(step)
            } else {
                VStack(spacing: 18) {
                    basicsCard
                    bodyCard
                    equipmentCard
                    trainingCard
                    goalCard
                }
            }
        }
    }

    @ViewBuilder
    private func stepContent(_ step: Int) -> some View {
        switch step {
        case 0:
            basicsCard
        case 1:
            bodyCard
        case 2:
            equipmentCard
        case 3:
            trainingCard
        default:
            goalCard
        }
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "基础信息", subtitle: "用于计算热量与训练负荷")

            VStack(alignment: .leading, spacing: 8) {
                Text("怎么称呼你")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                TextField("例如：小林", text: $draft.nickname)
                    .textInputAutocapitalization(.never)
                    .onChange(of: draft.nickname) { _, value in
                        if value.count > 30 {
                            draft.nickname = String(value.prefix(30))
                        }
                    }
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }

            Picker("性别", selection: $draft.sex) {
                ForEach(Sex.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $draft.age, in: 14...70) {
                HStack {
                    Text("年龄")
                    Spacer()
                    Text("\(draft.age) 岁")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            MetricSlider(
                title: "身高",
                value: $draft.heightCM,
                range: 140...210,
                step: 1,
                unit: "cm"
            )
        }
        .card()
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "身体数据", subtitle: "用于追踪体重、体脂与围度变化")

            MetricSlider(
                title: "体重",
                value: $draft.weightKG,
                range: 35...160,
                step: 0.5,
                unit: "kg"
            )

            MetricSlider(
                title: "体脂率",
                value: $draft.bodyFatPCT,
                range: 3...60,
                step: 0.5,
                unit: "%"
            )

            HStack {
                Text("BMI")
                Spacer()
                Text(String(format: "%.1f", draft.bmi))
                    .foregroundStyle(Theme.primaryText)
                Text(draft.bmiLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.accentText)
            }
            .font(.subheadline)

            MetricSlider(
                title: "腰围",
                value: $draft.waistCM,
                range: 50...150,
                step: 1,
                unit: "cm"
            )
            MetricSlider(
                title: "臂围",
                value: $draft.armCM,
                range: 20...60,
                step: 0.5,
                unit: "cm"
            )
            MetricSlider(
                title: "大腿围",
                value: $draft.thighCM,
                range: 35...90,
                step: 0.5,
                unit: "cm"
            )
            MetricSlider(
                title: "胸围",
                value: $draft.chestCM,
                range: 60...150,
                step: 1,
                unit: "cm"
            )
            MetricSlider(
                title: "臀围",
                value: $draft.hipCM,
                range: 60...150,
                step: 1,
                unit: "cm"
            )
        }
        .card()
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                SectionTitle(title: "可用器械", subtitle: "只安排你能用上的动作")
                Spacer(minLength: 0)
                equipmentCountBadge
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Equipment.allCases) { item in
                    equipmentTile(item)
                }
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    withAnimation(Motion.quick) {
                        if allEquipmentSelected {
                            draft.equipment.removeAll()
                        } else {
                            draft.equipment = Set(Equipment.allCases)
                        }
                    }
                } label: {
                    Label(
                        allEquipmentSelected ? "全部取消" : "全选",
                        systemImage: allEquipmentSelected ? "xmark.circle" : "checkmark.circle"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accentText)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.96))

                Spacer(minLength: 0)

                Text("至少选择一种")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 2)
        }
        .card()
    }

    private var equipmentCountBadge: some View {
        HStack(spacing: 2) {
            Text("\(draft.equipment.count)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accentText)
                .contentTransition(.numericText())
            Text("/ \(Equipment.allCases.count)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.accentText.opacity(0.10), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.accentText.opacity(0.20), lineWidth: 0.8)
        )
        .motionAnimation(Motion.quick, value: draft.equipment.count)
    }

    private var allEquipmentSelected: Bool {
        draft.equipment.count == Equipment.allCases.count
    }

    private func equipmentTile(_ item: Equipment) -> some View {
        let selected = draft.equipment.contains(item)

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                toggle(item)
            }
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Theme.accentText.opacity(0.18) : Theme.surface)
                        .frame(width: 34, height: 34)
                    Image(systemName: item.symbolName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selected ? Theme.accentText : Theme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(selected ? "已启用" : "未选择")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(selected ? Theme.accentText.opacity(0.9) : Theme.tertiaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selected ? Theme.accentText : Theme.tertiaryText.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? Theme.accentText.opacity(0.10) : Theme.surfaceStrong.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(
                        selected ? Theme.accentText.opacity(0.42) : Theme.stroke,
                        lineWidth: 1
                    )
            )
            .shadow(color: selected ? Theme.accentText.opacity(0.14) : Color.clear, radius: 7, y: 3)
        }
        .buttonStyle(CardPressStyle(scale: 0.97))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(
                title: "训练安排",
                subtitle: "每周 \(draft.weeklyDays) 练 · 每次 \(draft.sessionMinutes) 分钟 · \(draft.split.title)"
            )

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader("每周训练", systemImage: "calendar")
                AnimatedSegmentedControl(items: Array(1...7), selection: $draft.weeklyDays) { "\($0)" }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader("训练分化", systemImage: "square.grid.2x2")
                AnimatedSegmentedControl(items: SplitType.allCases, selection: $draft.split) { $0.title }
                Text(draft.split.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(draft.split)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
            .motionAnimation(Motion.quick, value: draft.split)

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader("单次时长", systemImage: "clock")
                AnimatedSegmentedControl(items: sessionMinuteOptions, selection: $draft.sessionMinutes) { "\($0) 分" }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader("训练经验", systemImage: "chart.bar.fill")
                AnimatedSegmentedControl(items: Experience.allCases, selection: $draft.experience) { $0.label }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldHeader("伤病或疼痛（选填）", systemImage: "bandage")
                TextField("例如：右膝半月板旧伤、腰容易酸", text: $draft.injuries, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: draft.injuries) { _, value in
                        if value.count > 200 {
                            draft.injuries = String(value.prefix(200))
                        }
                    }
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
        }
        .card()
    }

    private var sessionMinuteOptions: [Int] {
        Array(Set([30, 45, 60, 90, draft.sessionMinutes])).sorted()
    }

    private func fieldHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "你的目标", subtitle: "计划会围绕目标调整组次与负荷")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(GoalType.allCases) { item in
                    Button {
                        draft.goalType = item
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(draft.goalType == item ? Theme.accentText.opacity(0.16) : Theme.surfaceStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(draft.goalType == item ? Theme.accentText : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if draft.goalType != .endurance {
                MetricSlider(
                    title: "目标体重",
                    value: $draft.targetWeightKG,
                    range: 35...160,
                    step: 0.5,
                    unit: "kg"
                )
                MetricSlider(
                    title: "目标腰围",
                    value: targetWaistBinding,
                    range: 50...150,
                    step: 1,
                    unit: "cm"
                )
                MetricSlider(
                    title: "目标体脂率",
                    value: targetBodyFatBinding,
                    range: 3...60,
                    step: 0.5,
                    unit: "%"
                )
            }

            DatePicker(
                "目标日期",
                selection: $draft.targetDate,
                in: Date()...Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
                displayedComponents: .date
            )
            .font(.subheadline)

            if draft.bmi < 18.5 && draft.goalType == .loseFat {
                Label("当前 BMI 低于 18.5，不建议减脂。请选择重塑体型或增肌。", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .card()
    }

    private var targetWaistBinding: Binding<Double> {
        Binding(
            get: { draft.targetWaistCM ?? draft.waistCM },
            set: { draft.targetWaistCM = $0 }
        )
    }

    private var targetBodyFatBinding: Binding<Double> {
        Binding(
            get: { draft.targetBodyFatPCT ?? draft.bodyFatPCT },
            set: { draft.targetBodyFatPCT = $0 }
        )
    }

    private func toggle(_ item: Equipment) {
        if draft.equipment.contains(item) {
            draft.equipment.remove(item)
        } else {
            draft.equipment.insert(item)
        }
    }
}

struct MetricSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(display)\(unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.accentText)
        }
    }

    private var display: String {
        step < 1 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
