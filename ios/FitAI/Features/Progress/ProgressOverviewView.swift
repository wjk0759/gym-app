import Charts
import Foundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

private struct ProgressComparePair: Identifiable {
    let id = UUID()
    let before: ProgressPhoto
    let after: ProgressPhoto
}

/// One place to answer “Am I changing?”. The old app scattered weight, body
/// fat, adherence and weekly review across several cards. This screen keeps
/// the story in one scroll and leaves Today for action.
struct ProgressOverviewView: View {
    @Environment(AppStore.self) private var store

    @State private var metric: MetricChoice = .weight
    @State private var showBodyCheckIn = false
    @State private var photos: [ProgressPhoto] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var comparePair: ProgressComparePair?
    @State private var photoAlert = ""
    @State private var showPhotoAlert = false

    private enum MetricChoice: String, CaseIterable, Identifiable {
        case weight
        case bodyFat
        case waist

        var id: String { rawValue }

        var title: String {
            switch self {
            case .weight: return "体重"
            case .bodyFat: return "体脂"
            case .waist: return "腰围"
            }
        }

        var unit: String {
            switch self {
            case .weight: return "kg"
            case .bodyFat: return "%"
            case .waist: return "cm"
            }
        }
    }

    private var metrics: [BodyMetric] {
        store.bodyMetrics.sorted { $0.date < $1.date }
    }

    private var latest: BodyMetric? { metrics.last }
    private var first: BodyMetric? { metrics.first }

    private func metricValue(_ item: BodyMetric) -> Double {
        switch metric {
        case .weight: return item.weightKG
        case .bodyFat: return item.bodyFatPCT
        case .waist: return item.waistCM
        }
    }

    private var delta: Double {
        guard let first, let latest else { return 0 }
        return metricValue(latest) - metricValue(first)
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                heroMetrics
                chartCard
                photosCard
                trainingCard
                nutritionCard
                goalCard(store.profile.goalType)
                reviewLink
                disclaimer
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("变化")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showBodyCheckIn) {
            BodyCheckInSheet(manual: true)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $comparePair) { pair in
            ProgressPhotoCompareView(before: pair.before, after: pair.after)
        }
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCaptureView(
                title: "拍进展照",
                hint: "保持和上次相同的角度、光线和站姿，对比才有意义。",
                onImage: { image in
                    showCamera = false
                    savePhoto(image)
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        .onAppear {
            photos = ProgressPhotoStore.load()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    savePhoto(image)
                } else {
                    photoAlert = "这张照片没有读进来，换一张试试。"
                    showPhotoAlert = true
                }
                photoItem = nil
            }
        }
        .alert("照片没有保存", isPresented: $showPhotoAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(photoAlert)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBodyCheckIn = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记录身体数据")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THE LONG VIEW")
                .font(AppType.overline)
                .tracking(1.8)
                .foregroundStyle(Theme.cobalt)
            Text("变化")
                .font(AppType.display)
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Text("不是每天都要变，但一个月后应该看得出方向。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var heroMetrics: some View {
        HStack(spacing: 10) {
            startMetric(
                title: "起点",
                value: first.map { String(format: "%.1f", metricValue($0)) } ?? "—",
                unit: metric.unit
            )
            startMetric(
                title: "现在",
                value: latest.map { String(format: "%.1f", metricValue($0)) } ?? "—",
                unit: metric.unit
            )
            startMetric(
                title: "变化",
                value: metrics.count > 1 ? String(format: "%+.1f", delta) : "—",
                unit: metric.unit,
                accent: delta <= 0 ? Theme.primary : Theme.secondary
            )
        }
    }

    private func startMetric(
        title: String,
        value: String,
        unit: String,
        accent: Color = Theme.cobalt
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                Text(unit)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
            }
            Rectangle()
                .fill(accent)
                .frame(width: 22, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "趋势", subtitle: "最近 \(metrics.count) 次记录")
                Spacer()
                Picker("指标", selection: $metric) {
                    ForEach(MetricChoice.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            if metrics.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "还没有身体数据",
                    message: "先记录一次体重，之后这里会显示趋势。"
                )
            } else {
                Chart(metrics) { item in
                    LineMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(Theme.cobalt)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.cobalt.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("日期", item.date),
                        y: .value(metric.title, metricValue(item))
                    )
                    .foregroundStyle(Theme.ink)
                    .symbolSize(22)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 210)
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "进展照片", subtitle: "同一角度、同一光线，变化才看得清")
                Spacer()
                Text("\(photos.count)")
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }

            if photos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Theme.cobalt)
                    Text("还没有进展照片")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("先拍一张，之后同角度再拍一张，就能对比。")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack(spacing: 8) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍一张", systemImage: "camera.fill")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }

                if photos.count >= 2 {
                    Button {
                        guard let first = photos.first, let last = photos.last else { return }
                        comparePair = ProgressComparePair(before: first, after: last)
                    } label: {
                        Label("对比", systemImage: "rectangle.split.2x1")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.cobalt.opacity(0.20), lineWidth: 1)
                            }
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.97))
                }
            }

            Text("照片只保存在本机，不会上传，也不参与 AI 分析。")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func photoThumbnail(_ photo: ProgressPhoto) -> some View {
        VStack(spacing: 5) {
            Group {
                if let image = ProgressPhotoStore.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.surface)
                }
            }
            .frame(width: 92, height: 122)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture {
                guard let first = photos.first, first.id != photo.id else { return }
                comparePair = ProgressComparePair(before: first, after: photo)
            }
            .contextMenu {
                Button(role: .destructive) {
                    ProgressPhotoStore.delete(photo)
                    photos = ProgressPhotoStore.load()
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }

            Text(photo.date.formatted(.dateTime.month().day()))
                .font(AppType.micro)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard ProgressPhotoStore.add(image: image) != nil else {
            photoAlert = "照片没有保存成功，请检查存储空间后重试。"
            showPhotoAlert = true
            return
        }
        photos = ProgressPhotoStore.load()
        Haptics.success()
    }

    private var trainingCard: some View {
        let recent = store.sessions.filter {
            $0.date >= Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        }
        let weeks = max(1.0, 4.0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(title: "训练执行", subtitle: "最近 4 周")
                Spacer()
                Text("\(recent.count) 次")
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
            }

            HStack(spacing: 8) {
                EditorialMetric(title: "总训练", value: "\(recent.count)", unit: "次")
                EditorialMetric(
                    title: "周均",
                    value: String(format: "%.1f", Double(recent.count) / weeks),
                    unit: "次"
                )
                EditorialMetric(
                    title: "总容量",
                    value: "\(Int(recent.reduce(0) { $0 + $1.volume }))",
                    unit: "kg"
                )
            }

        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var nutritionCard: some View {
        let days = Set(
            store.foodLogs
                .filter {
                    $0.date >= Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
                }
                .map { FitnessDate.key($0.date) }
        ).count
        let progress = min(1, Double(days) / 28)
        return HStack(spacing: 14) {
            ProgressRing(progress: progress, lineWidth: 7, color: Theme.lime)
                .frame(width: 58, height: 58)
                .overlay {
                    Text("\(Int(progress * 100))%")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.ink)
                }
            VStack(alignment: .leading, spacing: 3) {
                Text("饮食记录")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("最近 28 天记录了 \(days) 天")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func goalCard(_ goal: GoalType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 36, height: 36)
                .background(Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("当前目标 · \(goal.label)")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text(goal.detail)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var reviewLink: some View {
        NavigationLink {
            PlanReviewView()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练复盘")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    private var disclaimer: some View {
        Text("体重会受水分、盐分和生理期影响，看趋势即可。")
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
            .lineSpacing(2)
    }
}

// MARK: - Photo comparison

private struct ProgressPhotoCompareView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto

    @Environment(\.dismiss) private var dismiss

    @State private var shareImage: UIImage?
    @State private var comparison: UIImage?
    @State private var showShare = false
    @State private var saveMessage = ""
    @State private var showSaveAlert = false

    private var beforeImage: UIImage? { ProgressPhotoStore.image(for: before) }
    private var afterImage: UIImage? { ProgressPhotoStore.image(for: after) }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorialHeader(
                        eyebrow: "Progress",
                        title: "放在一起看",
                        subtitle: "同一角度、同一光线，变化才有意义。"
                    )

                    if let beforeImage, let afterImage {
                        BeforeAfterSlider(before: beforeImage, after: afterImage)
                            .frame(height: 430)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
                            }

                        HStack {
                            compareLabel("开始", date: before.date, color: Theme.ink)
                            Spacer()
                            compareLabel("现在", date: after.date, color: Theme.secondary)
                        }

                        HStack(spacing: 8) {
                            Button {
                                saveComparison()
                            } label: {
                                Label("保存对比图", systemImage: "square.and.arrow.down")
                                    .font(AppType.caption.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(Theme.stroke, lineWidth: 1)
                                    }
                            }
                            .buttonStyle(SubtlePressStyle(scale: 0.97))
                            .disabled(comparison == nil)

                            Button {
                                shareComparison()
                            } label: {
                                Label("分享对比图", systemImage: "square.and.arrow.up")
                                    .font(AppType.caption.weight(.bold))
                                    .foregroundStyle(Theme.onPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(SubtlePressStyle(scale: 0.97))
                            .disabled(comparison == nil)
                        }

                    } else {
                        EmptyStateView(
                            icon: "photo",
                            title: "照片读取失败",
                            message: "可能已被删除或存储空间不足。"
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("进展对比")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareImage {
                    ProgressPhotoActivityView(items: [shareImage])
                }
            }
            .alert("保存到相册", isPresented: $showSaveAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(saveMessage)
            }
            .task {
                guard comparison == nil, let beforeImage, let afterImage else { return }
                comparison = ProgressPhotoExporter.comparisonImage(
                    before: before,
                    after: after,
                    beforeImage: beforeImage,
                    afterImage: afterImage
                )
            }
        }
    }

    private func saveComparison() {
        guard let image = comparison else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    saveMessage = "没有相册权限。请到系统设置里允许 FitAI 添加照片。"
                    showSaveAlert = true
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, error in
                    DispatchQueue.main.async {
                        saveMessage = success
                            ? "对比图已保存到相册。"
                            : "保存失败：\(error?.localizedDescription ?? "未知错误")"
                        showSaveAlert = true
                    }
                }
            }
        }
    }

    private func shareComparison() {
        guard let image = comparison else { return }
        shareImage = image
        showShare = true
    }

    private func compareLabel(_ title: String, date: Date, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppType.micro)
                .foregroundStyle(color)
            Text(date.formatted(.dateTime.year().month().day()))
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
    }
}

private struct BeforeAfterSlider: View {
    let before: UIImage
    let after: UIImage

    @State private var position: CGFloat = 0.5

    var body: some View {
        GeometryReader { geo in
            let width = max(1, geo.size.width)
            ZStack(alignment: .leading) {
                Image(uiImage: after)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: geo.size.height)
                    .clipped()

                Image(uiImage: before)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: geo.size.height)
                    .clipped()
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: width * position)
                    }

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .offset(x: width * position)
                    .shadow(color: .black.opacity(0.20), radius: 2)

                Circle()
                    .fill(Theme.primary)
                    .frame(width: 38, height: 38)
                    .overlay {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.onPrimary)
                    }
                    .overlay {
                        Circle().strokeBorder(Theme.inkSolid, lineWidth: 2)
                    }
                    .offset(x: width * position - 18)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                position = min(max(value.location.x / width, 0.04), 0.96)
                            }
                    )

                HStack {
                    Text("开始")
                    Spacer()
                    Text("现在")
                }
                .font(AppType.micro.weight(.bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    LinearGradient(
                        colors: [.black.opacity(0.34), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        position = min(max(value.location.x / width, 0.04), 0.96)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("进展照片对比")
        .accessibilityValue("\(Int(position * 100))% 开始照片")
    }
}
