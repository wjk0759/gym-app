import SwiftUI

extension EquipmentItemDetailView {
func equipmentInfoSection(for item: EquipmentItem) -> some View {
        let matches = matchingEquipment(for: item)
        let universalNames = matchingUniversalNames(for: item)

        return detailSection(
            index: "01",
            title: "所需器械",
            lead: "确认器械、握法和可替代方案，再开始动作。"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                equipmentInfoRow(
                    title: "器械类型",
                    value: item.equipment?.label ?? "未设置",
                    symbol: equipmentSymbol(item)
                )
                equipmentInfoRow(
                    title: "主要刺激",
                    value: item.muscle?.label ?? "全身",
                    symbol: "figure.strengthtraining.functional"
                )

                if matches.isEmpty && universalNames.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你还没有对应器械")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("去器械库添加后，这个动作会进入你的计划池。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            showEquipmentLibrary = true
                        } label: {
                            Label("去器械库添加", systemImage: "plus.circle")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        if !universalNames.isEmpty {
                            Text("你已勾选：\(universalNames.joined(separator: "、"))")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(Theme.cobalt)
                        }

                        if !matches.isEmpty {
                            Text("你已有")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(Theme.tertiaryText)

                            ForEach(matches) { match in
                                HStack(spacing: 9) {
                                    Image(systemName: equipmentSymbol(match))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.cobalt)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            Theme.cobalt.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        )
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(match.name)
                                            .font(AppType.caption.weight(.semibold))
                                            .foregroundStyle(Theme.ink)
                                        Text("\(match.trainableExercises.count) 个可练动作")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Theme.tertiaryText)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 3)
                            }
                        }

                        Button {
                            showEquipmentLibrary = true
                        } label: {
                            Label("去器械库", systemImage: "chevron.right")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.cobalt.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                Text("没有同款器械时，优先找同轨迹的替代动作；不要为了完成计划强行上重量。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

func matchingEquipment(for item: EquipmentItem) -> [EquipmentItem] {
        guard let exercise = item.exercise else { return [] }
        let groups = Set(exercise.equipmentTypes)
        return store.equipmentLibrary.filter { equipment in
            guard let group = EquipmentCatalog.group(for: equipment.equipmentType) else {
                return false
            }
            return groups.contains(group)
        }
    }

func matchingUniversalNames(for item: EquipmentItem) -> [String] {
        guard let exercise = item.exercise else { return [] }
        let groups = Set(exercise.equipmentTypes)
        return ExerciseLibrary.universalEquipment
            .filter {
                groups.contains($0.slug)
                    && store.selectedUniversalSlugs.contains($0.slug)
            }
            .map(\.name)
    }

func equipmentInfoRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 28, height: 28)
                .background(Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
        }
    }

func quickActions(for item: EquipmentItem, proxy: ScrollViewProxy) -> some View {
        let pinned = pinnedIDs.contains(item.id.uuidString)

        return HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: equipmentSymbol(item))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 29, height: 29)
                    .background(
                        Theme.lime.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                Text(item.name)
                    .font(AppType.callout.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 1) {
                quickActionButton("要点", icon: "checklist", active: detailTab == .points) {
                    withAnimation(Motion.smooth) {
                        detailTab = .points
                    }
                }

                quickActionButton("数据", icon: "chart.bar") {
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo("stats", anchor: .top)
                    }
                }

                if !isPreview {
                    quickActionButton("置顶", icon: pinned ? "pin.fill" : "pin", active: pinned) {
                        togglePin(for: item)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

func quickActionButton(
        _ title: String,
        icon: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(active ? Theme.ink : Theme.secondaryText)
            .frame(width: 44)
            .padding(.vertical, 5)
            .background(
                active ? Theme.lime.opacity(0.75) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
        .accessibilityLabel(title)
    }

func hero(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("动作学习预览")
                .font(AppType.overline)
                .tracking(1.4)
                .foregroundStyle(Theme.cobalt)

            Text(item.name)
                .font(AppType.hero)
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
                .padding(.top, 5)

            HStack(spacing: 6) {
                detailPill(item.muscle?.label ?? "未分类")
                detailPill(item.equipment?.label ?? "未设置")
                if AppConfig.exerciseVideosEnabled {
                    detailPill(videoURL != nil ? "教学视频" : "视频准备中", accent: videoURL != nil)
                }
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

func detailSection<Content: View>(
        index: String,
        title: String,
        lead: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(index)
                .font(AppType.overline)
                .tracking(1.2)
                .foregroundStyle(Theme.cobalt)

            Text(title)
                .font(AppType.title)
                .foregroundStyle(Theme.ink)
                .padding(.top, 3)

            Text(lead)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            content()
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .id(index)
    }

func coachCard(for item: EquipmentItem) -> some View {
        Button {
            store.sendChat(
                "请用简单步骤讲解\(item.name)的起始位置、发力顺序和常见错误。",
                skill: .trainer
            )
            showCoach = true
        } label: {
            HStack(spacing: 10) {
                CoachMark(size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text("动作细节还不确定？")
                        .font(AppType.callout.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 4)

                Text("问教练")
                    .font(AppType.micro.weight(.bold))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(13)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

func detailPill(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(AppType.micro)
            .foregroundStyle(accent ? Theme.ink : Theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                accent ? Theme.lime.opacity(0.75) : Theme.paper,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        accent ? Theme.ink.opacity(0.16) : Theme.stroke,
                        lineWidth: 1
                    )
            )
    }

func detailBadge(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(accent ? Theme.cobalt : Theme.onMedia.opacity(0.72))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.38), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        accent ? Theme.cobalt.opacity(0.22) : Color.white.opacity(0.10),
                        lineWidth: 0.8
                    )
            )
    }

func equipmentSymbol(_ item: EquipmentItem) -> String {
        if let equipment = item.equipment {
            return equipment.symbolName
        }
        guard let muscle = item.muscle else { return "dumbbell" }
        switch muscle {
        case .legs, .glutes, .core:
            return "figure.strengthtraining.functional"
        case .cardio:
            return "figure.run"
        case .chest, .back, .shoulders:
            return "figure.strengthtraining.traditional"
        case .arms:
            return "dumbbell"
        }
    }

func togglePin(for item: EquipmentItem) {
        var ids = pinnedIDs
        if ids.contains(item.id.uuidString) {
            ids.remove(item.id.uuidString)
        } else {
            ids.insert(item.id.uuidString)
        }
        pinnedEquipmentIDsRaw = ids.sorted().joined(separator: ",")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
