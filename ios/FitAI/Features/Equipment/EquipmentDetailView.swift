import AVKit
import Foundation
import SwiftUI
import UIKit

struct EquipmentItemDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pinnedEquipmentIDs") private var pinnedEquipmentIDsRaw = ""

    let itemID: UUID

    @State private var showDelete = false
    @State private var showCoach = false
    @State private var officialVideoURL: URL?

    private var item: EquipmentItem? {
        store.equipmentLibrary.first { $0.id == itemID }
    }

    private var videoURL: URL? {
        officialVideoURL ?? item?.videoURL.flatMap(URL.init(string:))
    }

    private var pinnedIDs: Set<String> {
        Set(pinnedEquipmentIDsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                AppScrollView {
                    if let item {
                        content(for: item, proxy: proxy)
                    } else {
                        EmptyStateView(
                            icon: "dumbbell",
                            title: "器械不存在",
                            message: "它可能已经被删除。"
                        )
                        .padding(20)
                    }
                }
            }
            .background(AppBackground())
            .navigationTitle("器械详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard store.useRemoteAI, let slug = item?.slug else { return }
                if let url = try? await APIClient.shared.officialVideoURL(slug: slug) {
                    officialVideoURL = url
                }
            }
            .confirmationDialog(
                "从器械库删除？",
                isPresented: $showDelete,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    store.removeEquipment(itemID)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后，下次生成计划不会再优先使用这件器械。")
            }
            .sheet(isPresented: $showCoach) {
                CoachChatView()
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func content(for item: EquipmentItem, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 16) {
            quickActions(for: item, proxy: proxy)
            hero(for: item)

            detailSection(
                index: "01",
                title: "视频讲解",
                lead: "先看动作讲解，再看后面要点，会更容易抓住发力顺序。"
            ) {
                videoContent(for: item)
            }

            detailSection(
                index: "02",
                title: "动作轨迹",
                lead: "先用轨迹示意建立动作路径，再在训练中把速度放慢。"
            ) {
                motionBoard(for: item)
            }

            detailSection(
                index: "03",
                title: "多角度示范",
                lead: "示范素材准备中。先用要点确认起始位置和身体角度。"
            ) {
                angleGrid(for: item)
            }

            detailSection(
                index: "04",
                title: "动作要点",
                lead: "下面的要点来自动作库和你的器械备注。"
            ) {
                pointsContent(for: item)
            }

            detailSection(
                index: "05",
                title: "训练肌群",
                lead: "主要训练 \(item.muscle?.label ?? "全身")，协同稳定由 \(supportMuscles(for: item).joined(separator: "、")) 参与。"
            ) {
                muscleContent(for: item)
            }

            detailSection(
                index: "06",
                title: "训练数据",
                lead: statsLead(for: item)
            ) {
                statsContent(for: item)
            }

            coachCard(for: item)

            Button(role: .destructive) {
                showDelete = true
            } label: {
                Text("从器械库删除")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Theme.danger.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.danger.opacity(0.18), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Text("出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。教学视频和示范素材由官方动作库提供。")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 6)
        }
        .padding(20)
        .padding(.bottom, 24)
    }

    private func quickActions(for item: EquipmentItem, proxy: ScrollViewProxy) -> some View {
        let pinned = pinnedIDs.contains(item.id.uuidString)

        return HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: equipmentSymbol(item))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 29, height: 29)
                    .background(
                        Theme.accent.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                Text(item.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 1) {
                quickActionButton("要点", icon: "checklist") {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        proxy.scrollTo("04", anchor: .top)
                    }
                }

                quickActionButton("历史", icon: "clock") {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        proxy.scrollTo("06", anchor: .top)
                    }
                }

                quickActionButton("图表", icon: "chart.bar") {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        proxy.scrollTo("06", anchor: .top)
                    }
                }

                quickActionButton("置顶", icon: pinned ? "pin.fill" : "pin", active: pinned) {
                    togglePin(for: item)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }

    private func quickActionButton(
        _ title: String,
        icon: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
            .frame(width: 44)
            .padding(.vertical, 5)
            .background(
                active ? Theme.accent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func hero(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("动作学习预览")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.accent)

            Text(item.name)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(.white)
                .padding(.top, 6)

            Text(heroDescription(for: item))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            HStack(spacing: 6) {
                detailPill(item.muscle?.label ?? "未分类")
                detailPill(item.equipment?.label ?? "未设置")
                detailPill(videoURL != nil ? "教学视频" : "视频准备中", accent: videoURL != nil)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func detailSection<Content: View>(
        index: String,
        title: String,
        lead: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(index)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.accent)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Text(lead)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondaryText)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)

            content()
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.067, green: 0.102, blue: 0.169),
                            Color(red: 0.047, green: 0.078, blue: 0.137)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
        .id(index)
    }

    @ViewBuilder
    private func videoContent(for item: EquipmentItem) -> some View {
        if let url = videoURL {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    detailBadge("官方教学视频", accent: true)
                        .padding(10)
                }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.18, blue: 0.24),
                                Color(red: 0.045, green: 0.078, blue: 0.125)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let data = item.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .opacity(0.32)
                } else {
                    Image(systemName: equipmentSymbol(item))
                        .font(.system(size: 66, weight: .light))
                        .foregroundStyle(Theme.accent.opacity(0.22))
                }

                VStack(spacing: 7) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 54, height: 54)
                        .background(Color.black.opacity(0.42), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.30), lineWidth: 1))

                    Text("教学视频准备中")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

                    Text("这件器械的官方示范视频还在准备中。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                detailBadge("视频待上线")
                    .padding(10)
            }
        }
    }

    private func motionBoard(for item: EquipmentItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.94, blue: 0.97),
                            Color(red: 0.78, green: 0.84, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ForEach(0..<3, id: \.self) { index in
                Ellipse()
                    .stroke(
                        Color(red: 0.10, green: 0.21, blue: 0.32).opacity(0.20),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 5])
                    )
                    .frame(
                        width: 250 - CGFloat(index) * 48,
                        height: 105 - CGFloat(index) * 22
                    )
                    .rotationEffect(.degrees(-16))
            }

            Image(systemName: equipmentSymbol(item))
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Color(red: 0.055, green: 0.11, blue: 0.18))
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text("保持轨迹稳定")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.11, green: 0.20, blue: 0.29))
                Text("起始位置、发力方向和还原速度，比盲目加重量更重要。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color(red: 0.16, green: 0.27, blue: 0.37).opacity(0.82))
                    .lineSpacing(1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.04))
                .frame(width: 28, height: 28)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(10)
        }
    }

    private func angleGrid(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(Array(["正面", "侧面", "发力", "细节"].enumerated()), id: \.offset) { index, label in
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(index < 2 ? 0.055 : 0.03))
                            Image(systemName: index < 2 ? equipmentSymbol(item) : "ellipsis")
                                .font(.system(size: 21, weight: .light))
                                .foregroundStyle(
                                    index < 2 ? Theme.accent.opacity(0.70) : Theme.tertiaryText
                                )
                        }
                        .frame(height: 58)

                        Text(label)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .background(
                        Color.white.opacity(0.025),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                    )
                }
            }

            Text("示范素材准备中；先用下面的动作要点确认起始位置和发力顺序。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(1.5)
        }
    }

    private func pointsContent(for item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(points(for: item).enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 11) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Theme.blue, in: Circle())

                    Text(point)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(item.notes.isEmpty
                 ? "先用轻重量确认动作路线，再逐步接近目标负荷。"
                 : "器械备注：\(item.notes)")
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.accent.opacity(0.90))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Theme.accent.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.accent.opacity(0.14), lineWidth: 0.8)
                )
        }
    }

    private func muscleContent(for item: EquipmentItem) -> some View {
        HStack(spacing: 14) {
            EquipmentBodyMap(muscle: item.muscle)
                .frame(width: 112, height: 172)

            VStack(alignment: .leading, spacing: 0) {
                Text("主要肌群")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)

                Text(item.muscle?.label ?? "全身")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 2)

                HStack(spacing: 4) {
                    ForEach(supportMuscles(for: item), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9.5))
                            .foregroundStyle(Theme.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                }
                .padding(.top, 7)

                Text("动作时优先感受 \(item.muscle?.label ?? "全身") 的发力，协同区域负责稳定与传导。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            Color.black.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func statsContent(for item: EquipmentItem) -> some View {
        let stats = detailStats(for: item)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                statMetric("\(stats.sessions)", label: "完成次数")
                statMetric(Int(stats.volume).formatted(), label: "累计容量 kg")
                statMetric("\(stats.sets)", label: "完成组数")
            }

            if stats.bars.isEmpty {
                Text("完成训练后自动生成容量与频率趋势。")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(1.5)
                    .padding(.top, 12)
            } else {
                let maxValue = max(stats.bars.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 6) {
                    Spacer(minLength: 0)
                    ForEach(Array(stats.bars.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accent.opacity(0.16)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: 34,
                                height: max(8, CGFloat(value / maxValue) * 58)
                            )
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 64, alignment: .bottom)
                .padding(.top, 12)

                Text("近 \(stats.bars.count) 次训练容量趋势")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 6)
            }
        }
    }

    private func statMetric(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func coachCard(for item: EquipmentItem) -> some View {
        Button {
            store.sendChat(
                "请用简单步骤讲解\(item.name)的起始位置、发力顺序和常见错误。",
                skill: .trainer
            )
            showCoach = true
        } label: {
            HStack(spacing: 10) {
                Text("AI")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.04))
                    .frame(width: 36, height: 36)
                    .background(Theme.accent, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("动作细节还不确定？")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color(red: 0.94, green: 0.99, blue: 0.95))
                    Text("让教练结合你的计划，解释起始位置、发力顺序和替代动作。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color(red: 0.88, green: 0.96, blue: 0.91).opacity(0.60))
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Text("问教练")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.04))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(13)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.28, blue: 0.20).opacity(0.82),
                        Color(red: 0.07, green: 0.14, blue: 0.10).opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func detailPill(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(accent ? Theme.accent : Theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                accent ? Theme.accent.opacity(0.10) : Color.white.opacity(0.035),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        accent ? Theme.accent.opacity(0.24) : Color.white.opacity(0.09),
                        lineWidth: 0.8
                    )
            )
    }

    private func detailBadge(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(accent ? Theme.accent : Theme.tertiaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.38), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        accent ? Theme.accent.opacity(0.22) : Color.white.opacity(0.10),
                        lineWidth: 0.8
                    )
            )
    }

    private func heroDescription(for item: EquipmentItem) -> String {
        if let instructions = item.exercise?.instructions, !instructions.isEmpty {
            return instructions
        }
        if !item.notes.isEmpty {
            return item.notes
        }
        return "先用稳定、可控的轨迹完成动作，再逐步增加重量和训练量。"
    }

    private func points(for item: EquipmentItem) -> [String] {
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

    private func supportMuscles(for item: EquipmentItem) -> [String] {
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

    private func detailStats(for item: EquipmentItem) -> EquipmentDetailStats {
        guard let slug = item.slug else { return EquipmentDetailStats() }

        var entries: [(date: Date, volume: Double, sets: Int)] = []
        for session in store.sessions {
            let matching = session.sets.filter { $0.slug == slug && $0.completed }
            guard !matching.isEmpty else { continue }

            let volume = matching.reduce(0.0) { partial, log in
                partial + log.weightKG * Double(log.reps)
            }
            entries.append((session.date, volume, matching.count))
        }

        entries.sort { $0.date < $1.date }

        return EquipmentDetailStats(
            sessions: entries.count,
            sets: entries.reduce(0) { $0 + $1.sets },
            volume: entries.reduce(0) { $0 + $1.volume },
            last: entries.last?.date,
            bars: entries.suffix(6).map { $0.volume }
        )
    }

    private func statsLead(for item: EquipmentItem) -> String {
        let stats = detailStats(for: item)
        guard stats.sessions > 0 else {
            return "完成一次包含这个动作的训练后，这里会生成专属数据。"
        }
        let last = stats.last?.formatted(.dateTime.month().day().hour().minute()) ?? ""
        return "已完成 \(stats.sessions) 次相关训练\(last.isEmpty ? "" : "，最近一次 \(last)")。"
    }

    private func equipmentSymbol(_ item: EquipmentItem) -> String {
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

    private func togglePin(for item: EquipmentItem) {
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

private struct EquipmentDetailStats {
    var sessions: Int = 0
    var sets: Int = 0
    var volume: Double = 0
    var last: Date?
    var bars: [Double] = []
}

private struct EquipmentBodyMap: View {
    let muscle: MuscleGroup?

    private let base = Color.white.opacity(0.09)
    private let accent = Theme.accent.opacity(0.76)
    private let accentShadow = Theme.accent.opacity(0.34)

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.07))
                .frame(width: 118, height: 118)
                .blur(radius: 18)

            bodyBase
            highlight
        }
        .frame(width: 112, height: 172)
    }

    private var bodyBase: some View {
        ZStack {
            Circle()
                .fill(base)
                .frame(width: 27, height: 27)
                .offset(y: -64)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(base)
                .frame(width: 60, height: 84)
                .offset(y: -8)

            Capsule()
                .fill(base)
                .frame(width: 14, height: 70)
                .rotationEffect(.degrees(-7))
                .offset(x: -39, y: -8)

            Capsule()
                .fill(base)
                .frame(width: 14, height: 70)
                .rotationEffect(.degrees(7))
                .offset(x: 39, y: -8)

            Capsule()
                .fill(base)
                .frame(width: 19, height: 82)
                .offset(x: -14, y: 56)

            Capsule()
                .fill(base)
                .frame(width: 19, height: 82)
                .offset(x: 14, y: 56)
        }
    }

    @ViewBuilder
    private var highlight: some View {
        if let muscle {
            switch muscle {
            case .chest:
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(accent)
                        .frame(width: 22, height: 18)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(accent)
                        .frame(width: 22, height: 18)
                }
                .offset(y: -24)
                .shadow(color: accentShadow, radius: 8)

            case .back:
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent)
                    .frame(width: 52, height: 48)
                    .offset(y: -14)
                    .shadow(color: accentShadow, radius: 8)

            case .core:
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(accent)
                    .frame(width: 34, height: 32)
                    .offset(y: 0)
                    .shadow(color: accentShadow, radius: 8)

            case .shoulders:
                HStack(spacing: 41) {
                    Circle()
                        .fill(accent)
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(accent)
                        .frame(width: 18, height: 18)
                }
                .offset(y: -35)
                .shadow(color: accentShadow, radius: 8)

            case .arms:
                HStack(spacing: 51) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 13, height: 54)
                        .rotationEffect(.degrees(-7))
                    Capsule()
                        .fill(accent)
                        .frame(width: 13, height: 54)
                        .rotationEffect(.degrees(7))
                }
                .offset(y: -6)
                .shadow(color: accentShadow, radius: 8)

            case .legs:
                HStack(spacing: 9) {
                    Capsule()
                        .fill(accent)
                        .frame(width: 17, height: 66)
                    Capsule()
                        .fill(accent)
                        .frame(width: 17, height: 66)
                }
                .offset(y: 42)
                .shadow(color: accentShadow, radius: 8)

            case .glutes:
                HStack(spacing: 4) {
                    Circle()
                        .fill(accent)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(accent)
                        .frame(width: 24, height: 24)
                }
                .offset(y: 22)
                .shadow(color: accentShadow, radius: 8)

            case .cardio:
                Image(systemName: "heart.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(accent)
                    .offset(y: -16)
                    .shadow(color: accentShadow, radius: 8)
            }
        }
    }
}
