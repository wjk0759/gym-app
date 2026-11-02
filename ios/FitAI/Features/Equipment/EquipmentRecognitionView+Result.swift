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

            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 8) {
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
                        Text("\(Int(candidate.confidence * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                    }

                    ProgressView(value: candidate.confidence)
                        .tint(candidate.confidence >= 0.6 ? Theme.primary : Theme.secondary)

                    if candidate.confidence < 0.6 {
                        Text("需要确认：这张图可能不是这个器械")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.coral)
                    }

                    HStack {
                        Button {
                            saveToLibrary(candidate)
                        } label: {
                            Label(
                                isSaved(candidate) ? "已保存" : "保存到器械库",
                                systemImage: isSaved(candidate) ? "checkmark.circle.fill" : "plus.circle"
                            )
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(isSaved(candidate) ? Theme.tertiaryText : Theme.cobalt)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaved(candidate))

                        Spacer()

                        if let onSelect {
                            Button {
                                onSelect(candidate.exercise)
                                dismiss()
                            } label: {
                                Label("加入已选", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(Theme.cobalt)
                            }
                            .buttonStyle(.plain)
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
                    .padding(.top, 2)
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
}
