import SwiftUI

extension EquipmentRecognitionView {
    var matchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("匹配器械")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(candidates.count) 个候选")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.cobalt)
                    Text("正在从动作库匹配…")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 8)
            } else if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !customAddedName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.cobalt)
                            Text("已加入器械库：\(customAddedName)")
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("可在「我的器械库」查看并关联动作；关联后会进入计划池。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if scanStatus == "unavailable" {
                        Text("识别服务暂时不可用")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        Text(warning.isEmpty
                             ? "请检查网络后重试；也可以手动搜索动作或添加器械。"
                             : warning)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if imageData != nil {
                            Button {
                                scanKey = UUID().uuidString
                                scan()
                            } label: {
                                Label("重新识别", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    } else if scanStatus == "not_gym_equipment" {
                        Text("这张照片里没有识别到健身器械")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(description.isEmpty
                             ? "请让器械完整进入画面，避免只拍局部或文字。"
                             : description)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if notInLibrary {
                        Text(equipmentName.isEmpty
                             ? "识别到器械，但动作库暂未收录"
                             : "识别到「\(equipmentName)」，动作库暂未收录")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if !description.isEmpty {
                            Text(description)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            showAddCustom = true
                        } label: {
                            Label("补全器械信息", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text(selectedImage == nil
                             ? "先拍摄或选择一张器械照片。"
                             : "暂未识别到动作库中的器械，可以直接补全并加入个人库。")
                            .font(AppType.callout.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if !description.isEmpty {
                            Text(description)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if selectedImage != nil && customAddedName.isEmpty {
                        Text("拍摄建议：让器械完整进入画面，并尽量把品牌/动作标签拍清楚；暗光、遮挡或只拍局部都会降低识别率。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            } else {
                if equipmentOptions.count > 1 {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("最可能是")
                            .font(AppType.overline)
                            .tracking(0.8)
                            .foregroundStyle(Theme.tertiaryText)

                        LazyVGrid(
                            columns: [
                                GridItem(
                                    .adaptive(minimum: 108),
                                    spacing: 8,
                                    alignment: .leading
                                )
                            ],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(equipmentOptions) { option in
                                Button {
                                    selectEquipment(option)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .font(AppType.caption.weight(.semibold))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.72)
                                        Text("\(Int(option.confidence * 100))%")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundStyle(
                                        selectedEquipmentSlug == option.slug
                                            ? Theme.onPrimary
                                            : Theme.ink
                                    )
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        selectedEquipmentSlug == option.slug
                                            ? Theme.primary
                                            : Theme.paper,
                                        in: Capsule(style: .continuous)
                                    )
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(Theme.stroke, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("不确定时点另一个候选，动作会跟着切换。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else if !equipmentName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.cobalt)
                        Text("识别到 \(equipmentName)")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }

                if !isScanning,
                   !equipmentName.isEmpty,
                   (
                       equipmentName.contains("深蹲")
                       || equipmentName.contains("腿举")
                       || equipmentName.contains("倒蹬")
                   ) {
                    Text("这类器械容易和坐姿划船/腿举混淆。如果不对，点下方「从器械库选择」。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                resultSection
            }

            if !isScanning, imageData != nil {
                Button {
                    Haptics.tap()
                    showEquipmentPicker = true
                } label: {
                    Label("识别不对？从器械库选择", systemImage: "square.grid.2x2")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Theme.paper,
                            in: Capsule(style: .continuous)
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.98))
            }
        }
        .card()
    }
}
