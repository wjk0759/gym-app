import AVKit
import Charts
import Foundation
import SwiftUI
import UIKit

struct EquipmentItemDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pinnedEquipmentIDs") private var pinnedEquipmentIDsRaw = ""

    private let itemID: UUID?
    private let previewExercise: Exercise?

    @State private var showDelete = false
    @State private var showCoach = false
    @State private var officialVideoURL: URL?
    @State private var statsPeriod: EquipmentStatsPeriod = .ninetyDays
    @State private var statsMetric: EquipmentStatsMetric = .volume
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var customEnd = Date()

    init(itemID: UUID) {
        self.itemID = itemID
        self.previewExercise = nil
    }

    init(exercise: Exercise) {
        self.itemID = nil
        self.previewExercise = exercise
    }

    private var item: EquipmentItem? {
        if let previewExercise {
            return EquipmentItem(
                name: previewExercise.nameZH,
                slug: previewExercise.slug,
                muscle: previewExercise.muscle,
                equipment: previewExercise.equipment,
                videoURL: previewExercise.videoURL?.absoluteString,
                notes: ""
            )
        }
        guard let itemID else { return nil }
        return store.equipmentLibrary.first { $0.id == itemID }
    }

    private var isPreview: Bool {
        previewExercise != nil
    }

    private var videoURL: URL? {
        officialVideoURL ?? item?.videoURL.flatMap(URL.init(string:))
    }

    private var pinnedIDs: Set<String> {
        Set(pinnedEquipmentIDsRaw.split(separator: ",").map(String.init))
    }

    private var customRangeInvalid: Bool {
        statsPeriod == .custom && customStart > customEnd
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
            .navigationTitle(isPreview ? "动作详情" : "器械详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard let slug = item?.slug else { return }
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
                    if let itemID {
                        store.removeEquipment(itemID)
                    }
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

            if !isPreview {
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
            }

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
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo("04", anchor: .top)
                    }
                }

                quickActionButton("数据", icon: "chart.bar") {
                    withAnimation(Motion.smooth) {
                        proxy.scrollTo("06", anchor: .top)
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
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
            .frame(width: 44)
            .padding(.vertical, 5)
            .background(
                active ? Theme.accent.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.94))
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
            LoopingVideoPlayer(url: url)
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

                    Text(isPreview ? "这个动作的官方示范视频还在准备中。" : "这件器械的官方示范视频还在准备中。")
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

    @ViewBuilder
    private func motionBoard(for item: EquipmentItem) -> some View {
        if let exercise = item.exercise,
           let startURL = exercise.motionStartURL,
           let endURL = exercise.motionEndURL {
            FrameMotionBoard(startURL: startURL, endURL: endURL, title: item.name)
        } else {
            placeholderMotionBoard(for: item)
        }
    }

    private func placeholderMotionBoard(for item: EquipmentItem) -> some View {
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
                        colors: [
                            Color(red: 0.035, green: 0.075, blue: 0.12),
                            Color(red: 0.055, green: 0.10, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                )
                .accessibilityLabel("人体正面和背面肌肉示意图，重点训练\(primary)，\(support.joined(separator: "、"))")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("重点 \(primary)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
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

    private func statsContent(for item: EquipmentItem) -> some View {
        let stats = detailStats(for: item)
        let lastValue = stats.points.last.map {
            formattedMetricValue(metricValue($0, metric: statsMetric), metric: statsMetric)
        } ?? "—"
        let volumeValue = stats.sessions > 0 ? Int(stats.volume).formatted() : "—"
        let weightValue = stats.sessions > 0
            ? (stats.maxWeight > 0 ? formattedMetricValue(stats.maxWeight, metric: .maxWeight) : "自重")
            : "—"
        let oneRepMaxValue = stats.sessions > 0 && stats.best1RM > 0
            ? formattedMetricValue(stats.best1RM, metric: .oneRepMax)
            : "—"
        let chartValues = stats.points.map { metricValue($0, metric: statsMetric) }
        let chartCeiling = max(chartValues.max() ?? 0, 1) * 1.12

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                statMetric(volumeValue, label: "容量记录", note: "kg · 累计")
                statMetric(weightValue, label: "重量记录", note: "kg · 单组最重")
                statMetric(oneRepMaxValue, label: "1RM 预测", note: "kg · Epley")
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("记录趋势")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                    Text(statsMetric.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                Text("\(lastValue) \(statsMetric.unit)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 18)

            Text("统计周期")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 16)

            HStack(spacing: 4) {
                ForEach(EquipmentStatsPeriod.allCases) { period in
                    statsOption(period.rawValue, active: statsPeriod == period) {
                        statsPeriod = period
                    }
                }
            }
            .padding(.top, 6)

            if statsPeriod == .custom {
                HStack(spacing: 6) {
                    customDateControl("开始", selection: $customStart)
                    Text("—")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tertiaryText)
                    customDateControl("结束", selection: $customEnd)
                }
                .padding(.top, 8)

                if customRangeInvalid {
                    Text("开始日期不能晚于结束日期。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 6)
                }
            }

            HStack(spacing: 4) {
                ForEach(EquipmentStatsMetric.allCases) { metric in
                    statsOption(metric.rawValue, active: statsMetric == metric) {
                        statsMetric = metric
                    }
                }
            }
            .padding(.top, 10)

            if stats.points.isEmpty {
                VStack(spacing: 5) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("这个周期还没有训练记录")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text("换一个周期，或完成一次这个动作的训练。")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .background(
                    Color.white.opacity(0.025),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
                .padding(.top, 10)
            } else {
                Chart(stats.points) { point in
                    AreaMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.26), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(Theme.accent)
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: 2.3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", point.date),
                        y: .value(statsMetric.rawValue, metricValue(point, metric: statsMetric))
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(24)
                }
                .chartYScale(domain: 0.0...chartCeiling)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month().day()))
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.white.opacity(0.05))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number.rounded()))")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(Color.white.opacity(0.012))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 180)
                .padding(.top, 10)
            }

            Text("每个点代表一次有该动作的训练记录。1RM 为 Epley 公式估算，仅用于趋势对比，不等于实测极限。")
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
                .lineSpacing(2)
                .padding(.top, 9)
        }
    }

    private func statMetric(_ value: String, label: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(note)
                .font(.system(size: 8))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
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

    private func statsOption(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    active ? Theme.accent.opacity(0.12) : Color.white.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            active ? Theme.accent.opacity(0.28) : Color.white.opacity(0.07),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func customDateControl(_ title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiaryText)
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
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

    private func allChartPoints(for item: EquipmentItem) -> [EquipmentChartPoint] {
        guard let slug = item.slug else { return [] }

        var points: [EquipmentChartPoint] = []
        for session in store.sessions {
            let matching = session.sets.filter { $0.slug == slug && $0.completed }
            guard !matching.isEmpty else { continue }

            let volume = matching.reduce(0.0) { partial, log in
                partial + log.weightKG * Double(log.reps)
            }
            let maxWeight = matching.map(\.weightKG).max() ?? 0
            let estimated1RM = matching.reduce(0.0) { partial, log in
                guard log.weightKG > 0 else { return partial }
                let estimate = log.weightKG * (1 + Double(log.reps) / 30)
                return max(partial, estimate)
            }

            points.append(
                EquipmentChartPoint(
                    date: session.date,
                    volume: volume,
                    sets: matching.count,
                    maxWeight: maxWeight,
                    estimated1RM: estimated1RM
                )
            )
        }

        return points.sorted { $0.date < $1.date }
    }

    private func detailStats(for item: EquipmentItem) -> EquipmentDetailStats {
        let all = allChartPoints(for: item)
        let now = Date()
        let calendar = Calendar.current
        let start: Date?
        let end: Date?

        switch statsPeriod {
        case .week:
            start = calendar.date(byAdding: .day, value: -7, to: now)
            end = now
        case .month:
            start = calendar.date(byAdding: .day, value: -30, to: now)
            end = now
        case .ninetyDays:
            start = calendar.date(byAdding: .day, value: -90, to: now)
            end = now
        case .all:
            start = nil
            end = nil
        case .custom:
            if customRangeInvalid { return EquipmentDetailStats() }
            start = calendar.startOfDay(for: customStart)
            end = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: customEnd)
            )
        }

        let points = all.filter { point in
            if let start, point.date < start { return false }
            if let end, point.date >= end { return false }
            return true
        }

        return EquipmentDetailStats(
            points: points,
            sessions: points.count,
            sets: points.reduce(0) { $0 + $1.sets },
            volume: points.reduce(0) { $0 + $1.volume },
            maxWeight: points.reduce(0) { max($0, $1.maxWeight) },
            best1RM: points.reduce(0) { max($0, $1.estimated1RM) },
            last: points.last?.date
        )
    }

    private func statsLead(for item: EquipmentItem) -> String {
        if customRangeInvalid {
            return "开始日期不能晚于结束日期。"
        }
        let stats = detailStats(for: item)
        guard stats.sessions > 0 else {
            return "所选周期还没有这个动作的训练记录。"
        }
        let last = stats.last?.formatted(.dateTime.month().day().hour().minute()) ?? ""
        return "\(statsPeriod.rawValue) · \(stats.sessions) 次训练 / \(stats.sets) 组\(last.isEmpty ? "" : "，最近一次 \(last)")。"
    }

    private func metricValue(_ point: EquipmentChartPoint, metric: EquipmentStatsMetric) -> Double {
        switch metric {
        case .volume:
            return point.volume
        case .sets:
            return Double(point.sets)
        case .maxWeight:
            return point.maxWeight
        case .oneRepMax:
            return point.estimated1RM
        }
    }

    private func formattedMetricValue(_ value: Double, metric: EquipmentStatsMetric) -> String {
        if metric == .sets {
            return "\(Int(value.rounded()))"
        }
        guard value > 0 else { return "—" }
        return value.rounded() == value
            ? Int(value).formatted()
            : String(format: "%.1f", value)
    }

    private func muscleMapAsset(for muscle: MuscleGroup?) -> String {
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

private enum EquipmentStatsPeriod: String, CaseIterable, Identifiable, Equatable {
    case week = "7天"
    case month = "30天"
    case ninetyDays = "90天"
    case all = "全部"
    case custom = "自定义"

    var id: String { rawValue }
}

private enum EquipmentStatsMetric: String, CaseIterable, Identifiable, Equatable {
    case volume = "容量"
    case sets = "组数"
    case maxWeight = "最大重量"
    case oneRepMax = "1RM 估算"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .sets:
            return "组"
        default:
            return "kg"
        }
    }
}

private struct EquipmentChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let volume: Double
    let sets: Int
    let maxWeight: Double
    let estimated1RM: Double

    init(date: Date, volume: Double, sets: Int, maxWeight: Double, estimated1RM: Double) {
        self.id = UUID()
        self.date = date
        self.volume = volume
        self.sets = sets
        self.maxWeight = maxWeight
        self.estimated1RM = estimated1RM
    }
}

private struct EquipmentDetailStats {
    var points: [EquipmentChartPoint] = []
    var sessions: Int = 0
    var sets: Int = 0
    var volume: Double = 0
    var maxWeight: Double = 0
    var best1RM: Double = 0
    var last: Date?
}
