import SwiftUI

extension EquipmentItemDetailView {
func pointsContent(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(points(for: item).enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 11) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.onMedia)
                        .frame(width: 24, height: 24)
                        .background(Theme.blue, in: Circle())

                    Text(point)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink.opacity(0.82))
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(item.notes.isEmpty
                 ? "先用轻重量确认动作路线，再逐步接近目标负荷。"
                 : "器械备注：\(item.notes)")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.cobalt.opacity(0.90))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Theme.cobalt.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.cobalt.opacity(0.14), lineWidth: 0.8)
                )
        }
    }

func muscleContent(for item: EquipmentItem) -> some View {
        let primary = item.muscle?.label ?? "全身"
        let support = supportMuscles(for: item)

        return VStack(alignment: .leading, spacing: 0) {
            Text("人体肌肉的部位训练概况")
                .font(.system(size: 10))
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            Image(muscleMapAsset(for: item.muscle))
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Theme.inkSolid, Theme.inkSolid.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.onMedia.opacity(0.08), lineWidth: 0.8)
                )
                .accessibilityLabel("人体正面和背面肌肉示意图，重点训练\(primary)，\(support.joined(separator: "、"))")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("重点 \(primary)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryText)
                Text("辅助 \(support.joined(separator: " · "))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 9)

            Text("解剖示意图：OpenStax / Nefronus · CC BY-SA 4.0")
                .font(.system(size: 8))
                .foregroundStyle(Theme.tertiaryText.opacity(0.62))
                .padding(.top, 7)
        }
    }

func points(for item: EquipmentItem) -> [String] {
        var result = (item.exercise?.instructions ?? "")
            .components(separatedBy: CharacterSet(charactersIn: "。；;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let general = [
            "先调整座位、靠垫或把手高度，确认起始位置稳定，再开始发力。",
            "全程保持核心收紧、呼吸自然；最后几次也不要靠惯性甩动。",
            "如果出现关节刺痛、麻木或明显代偿，降低重量或停止动作。"
        ]

        for point in general where result.count < 3 {
            result.append(point)
        }

        return Array(result.prefix(5))
    }

func supportMuscles(for item: EquipmentItem) -> [String] {
        guard let muscle = item.muscle else { return ["核心", "稳定"] }
        switch muscle {
        case .chest:
            return ["肩", "手臂"]
        case .back:
            return ["手臂", "核心"]
        case .legs:
            return ["臀", "核心"]
        case .glutes:
            return ["腿", "核心"]
        case .shoulders:
            return ["手臂", "核心"]
        case .arms:
            return ["肩", "核心"]
        case .core:
            return ["背", "臀"]
        case .cardio:
            return ["腿", "核心"]
        }
    }

func muscleMapAsset(for muscle: MuscleGroup?) -> String {
        guard let muscle else { return "MuscleMapCardio" }
        switch muscle {
        case .chest:
            return "MuscleMapChest"
        case .back:
            return "MuscleMapBack"
        case .legs:
            return "MuscleMapLegs"
        case .glutes:
            return "MuscleMapGlutes"
        case .shoulders:
            return "MuscleMapShoulders"
        case .arms:
            return "MuscleMapArms"
        case .core:
            return "MuscleMapCore"
        case .cardio:
            return "MuscleMapCardio"
        }
    }

}
