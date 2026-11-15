import SwiftUI
import UIKit

// MARK: - History

/// The private body-analysis archive. Photos are fetched with the signed-in
/// user's token, never through a public URL.
struct BodyAnalysisHistoryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.bodyAnalyses.isEmpty {
                        emptyCard
                    } else {
                        ForEach(store.bodyAnalyses) { analysis in
                            NavigationLink {
                                BodyAnalysisDetailView(analysis: analysis)
                            } label: {
                                historyRow(analysis)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("照片存于私有目录，仅本人登录后可查看。分析结果只作训练重点参考。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("体型分析历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有分析记录")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
            Text("拍一张全身照，AI 会给出训练重点。分析记录会在这里按时间排列。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func historyRow(_ analysis: BodyAnalysis) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BodyAnalysisPhotoView(analysis: analysis, thumbnail: true)
                .frame(width: 78, height: 98)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                    Spacer(minLength: 6)
                    if analysis.appliedToPlan {
                        TagChip(text: "已应用", selected: true)
                    }
                }

                Text(analysis.summary)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 5) {
                    ForEach(analysis.focusAreas.prefix(3)) { muscle in
                        Text(muscle.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Theme.cobalt)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Theme.cobalt.opacity(0.08),
                                in: Capsule(style: .continuous)
                            )
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}

// MARK: - Detail

struct BodyAnalysisDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let analysis: BodyAnalysis

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if analysis.hasPhoto == true {
                    BodyAnalysisPhotoView(analysis: analysis)
                        .aspectRatio(4 / 5, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }

                HStack(spacing: 8) {
                    Text(analysis.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                    Spacer()
                    if analysis.appliedToPlan {
                        TagChip(text: "已应用到计划", selected: true)
                    }
                }

                BodyAnalysisResultSummary(analysis: analysis)
                    .card()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        if isDeleting {
                            ProgressView()
                                .tint(Theme.danger)
                        } else {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        Text("删除这次分析")
                            .font(AppType.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Theme.danger.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Theme.danger.opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeleting)
            }
            .padding(.horizontal, 20)
            .appPageTopPadding()
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("体型分析")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "删除这次体型分析？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("删除分析记录和照片", role: .destructive) {
                isDeleting = true
                Task {
                    if await store.deleteBodyAnalysis(analysis) {
                        dismiss()
                    }
                    isDeleting = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("云端记录和私有照片会一起删除，无法恢复。")
        }
    }
}

// MARK: - Shared result body

struct BodyAnalysisResultSummary: View {
    let analysis: BodyAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("分析结果")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("参考置信度 \(Int(analysis.confidence * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            Text(analysis.summary)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("建议训练重点")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(analysis.focusAreas) { muscle in
                        TagChip(text: muscle.label, selected: true)
                    }
                }
            }

            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(analysis.recommendations, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Theme.cobalt)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(item)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text(analysis.disclaimer)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Private photo

/// Loads a persisted analysis photo through the authenticated API and caches
/// successful downloads in memory. No public URL is ever constructed.
struct BodyAnalysisPhotoView: View {
    let analysis: BodyAnalysis
    var thumbnail = false

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var failed = false

    var body: some View {
        ZStack {
            Theme.ink.opacity(0.04)

            if let image {
                if thumbnail {
                    GeometryReader { proxy in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    }
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }
            } else if analysis.hasPhoto == true {
                if isLoading {
                    ProgressView()
                } else if failed {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: thumbnail ? 20 : 28, weight: .medium))
                        if !thumbnail {
                            Text("照片加载失败")
                                .font(.system(size: 10, weight: .medium))
                            Button("重新加载") {
                                Task { await load(force: true) }
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.cobalt)
                        }
                    }
                    .foregroundStyle(Theme.tertiaryText)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: thumbnail ? 22 : 34, weight: .light))
                    if !thumbnail {
                        Text("这次分析没有保存照片")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .foregroundStyle(Theme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: analysis.id) {
            await load(force: false)
        }
    }

    @MainActor
    private func load(force: Bool) async {
        guard analysis.hasPhoto == true else { return }
        guard !isLoading else { return }
        if !force, image != nil { return }
        if force {
            image = nil
        }
        isLoading = true
        failed = false
        image = await BodyAnalysisPhotoLoader.shared.image(
            for: analysis.id,
            thumbnail: thumbnail
        )
        failed = image == nil
        isLoading = false
    }
}

@MainActor
private final class BodyAnalysisPhotoLoader {
    static let shared = BodyAnalysisPhotoLoader()

    private var images: [String: UIImage] = [:]
    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func image(for id: UUID, thumbnail: Bool) async -> UIImage? {
        let key = "\(id.uuidString.lowercased())-\(thumbnail ? "thumb" : "full")"
        if let cached = images[key] {
            return cached
        }
        if let task = tasks[key] {
            return await task.value
        }

        let task = Task<UIImage?, Never> {
            guard let data = try? await APIClient.shared.fetchBodyAnalysisPhoto(
                clientID: id,
                thumbnail: thumbnail
            ), let image = UIImage(data: data) else {
                return nil
            }
            return image
        }
        tasks[key] = task
        let image = await task.value
        tasks[key] = nil
        if let image {
            images[key] = image
        }
        return image
    }
}
