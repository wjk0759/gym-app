import SwiftUI

extension ProfileFormView {
    var goalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "你的目标", subtitle: "计划会围绕目标调整组次与负荷")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(GoalType.allCases) { item in
                    Button {
                        draft.goalType = item
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.label)
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(item.detail)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(draft.goalType == item ? Theme.cobalt.opacity(0.08) : Theme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    draft.goalType == item ? Theme.cobalt : Theme.stroke,
                                    lineWidth: 1
                                )
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
            .font(AppType.callout)

            if draft.bmi < 18.5 && draft.goalType == .loseFat {
                Label("当前 BMI 低于 18.5，不建议减脂。请选择重塑体型或增肌。", systemImage: "exclamationmark.triangle.fill")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .card()
    }

    var targetWaistBinding: Binding<Double> {
        Binding(
            get: { draft.targetWaistCM ?? draft.waistCM },
            set: { draft.targetWaistCM = $0 }
        )
    }

    var targetBodyFatBinding: Binding<Double> {
        Binding(
            get: { draft.targetBodyFatPCT ?? draft.bodyFatPCT },
            set: { draft.targetBodyFatPCT = $0 }
        )
    }
}
