import Photos
import SwiftUI
import UIKit

struct ProgressPhotoCompareView: View {
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
                    saveMessage = "没有相册权限。请到系统设置里允许叫练添加照片。"
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
