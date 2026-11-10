import SwiftUI
import UIKit

extension EquipmentLibraryView {
    func libraryRow(_ item: EquipmentItem, pinned: Set<String>) -> some View {
        HStack(spacing: 12) {
            libraryThumbnail(item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(equipmentSubtitle(item))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            if pinned.contains(item.id.uuidString) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .accessibilityLabel("已置顶")
            }

            if AppConfig.exerciseVideosEnabled {
                Text(item.videoURL != nil ? "视频" : "准备中")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(item.videoURL != nil ? Theme.cobalt : Theme.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        item.videoURL != nil ? Theme.cobalt.opacity(0.10) : Theme.ink.opacity(0.035),
                        in: Capsule(style: .continuous)
                    )
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    func equipmentSubtitle(_ item: EquipmentItem) -> String {
        if item.equipmentType != nil {
            return "\(item.trainableExercises.count) 个可练动作"
        }
        return "\(item.muscle?.label ?? "未分类") · \(item.equipment?.label ?? "未设置")"
    }

    func libraryThumbnail(_ item: EquipmentItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.ink.opacity(0.035))
            if let data = item.photoData {
                EquipmentThumbnail(itemID: item.id, data: data)
            } else {
                Image(systemName: equipmentSymbol(item))
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.cobalt)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}
