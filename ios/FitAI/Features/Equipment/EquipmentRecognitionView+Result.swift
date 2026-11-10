import SwiftUI

extension EquipmentRecognitionView {
    var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "识别结果",
                subtitle: candidates.first.map {
                    $0.confidence < 0.6 ? "置信度较低，请从候选中确认" : "点击查看动作要领"
                }
            )

            equipmentCard

            if !candidates.isEmpty {
                Text("可练动作 \(candidates.count)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)

                ForEach(candidates) { candidate in
                    exerciseRow(candidate)
                }
            }

            Button {
                showAddCustom = true
            } label: {
                Label("都不是？补全器械信息", systemImage: "plus.circle")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.paper, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }
            .buttonStyle(SubtlePressStyle(scale: 0.98))
        }
    }

    /// 器械卡：保存的是「器械」，不是单个动作。
    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(equipmentName.isEmpty ? "识别到的器械" : equipmentName)
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("可练 \(candidates.count) 个动作")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if let confidence = equipmentOptions.first?.confidence {
                    Text("\(Int(confidence * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                }
            }

            Button {
                saveEquipmentAndExercises()
            } label: {
                Label(
                    isEquipmentSaved ? "已加入器械库" : "加入我的器械库",
                    systemImage: isEquipmentSaved ? "checkmark.circle.fill" : "plus.circle"
                )
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isEquipmentSaved ? Theme.tertiaryText : Theme.cobalt)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    (isEquipmentSaved ? Theme.ink.opacity(0.04) : Theme.cobalt.opacity(0.10)),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isEquipmentSaved ? Theme.stroke : Theme.cobalt.opacity(0.20),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isEquipmentSaved)
        }
        .padding(12)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func exerciseRow(_ candidate: EquipmentCandidate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.exercise.nameZH)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(candidate.exercise.muscle.label) · \(candidate.exercise.equipment.label)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button {
                selectedExercise = candidate.exercise
            } label: {
                Text("查看动作 ›")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedExercise = candidate.exercise
        }
    }
}
