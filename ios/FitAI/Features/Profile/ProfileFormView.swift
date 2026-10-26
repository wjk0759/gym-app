import Foundation
import SwiftUI

struct ProfileFormView: View {
    @Binding var draft: UserProfile

    var body: some View {
        VStack(spacing: 18) {
            basicsCard
            bodyCard
            equipmentCard
            trainingCard
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
                    .foregroundStyle(.white)
                Text(draft.bmiLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
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
            SectionTitle(title: "可用器械", subtitle: "只安排你能用上的动作")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Equipment.allCases) { item in
                    Button {
                        toggle(item)
                    } label: {
                        TagChip(
                            text: item.label,
                            selected: draft.equipment.contains(item)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "训练安排", subtitle: "之后可以随时调整")

            Stepper(value: $draft.weeklyDays, in: 1...7) {
                HStack {
                    Text("每周训练")
                    Spacer()
                    Text("\(draft.weeklyDays) 天")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("训练分化")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Picker("训练分化", selection: $draft.split) {
                    ForEach(SplitType.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                Text(draft.split.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text("单次时长")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Picker("单次时长", selection: $draft.sessionMinutes) {
                    ForEach(Array(Set([30, 45, 60, 90, 120, draft.sessionMinutes])).sorted(), id: \.self) { minutes in
                        Text("\(minutes) 分钟").tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("训练经验")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Picker("训练经验", selection: $draft.experience) {
                    ForEach(Experience.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("伤病或疼痛（选填）")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
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
                                .foregroundStyle(.white)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(draft.goalType == item ? Theme.accent.opacity(0.16) : Theme.surfaceStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(draft.goalType == item ? Theme.accent : Color.clear, lineWidth: 1)
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
                    .foregroundStyle(.white)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.accent)
        }
    }

    private var display: String {
        step < 1 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
