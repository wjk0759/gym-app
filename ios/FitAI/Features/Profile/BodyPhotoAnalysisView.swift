import PhotosUI
import SwiftUI
import UIKit

struct BodyPhotoAnalysisView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var analysisKey = UUID().uuidString
    @State private var analysis: BodyAnalysis?
    @State private var isAnalyzing = false
    @State private var isLoadingPhoto = false
    @State private var consent = false
    @State private var showCamera = false
    @State private var message = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    photoStage
                    guideRow
                    consentCard
                    analyzeButton

                    if let analysis {
                        resultCard(analysis)
                    }

                    disclaimer
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("体型照片分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await load(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    title: "拍摄体型照片",
                    hint: "保持自然站姿，让全身完整进入画面。",
                    onImage: { picked in
                        apply(picked)
                        showCamera = false
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            .alert("照片没有读进来", isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("VISION / 体型分析")
                    .font(AppType.overline)
                    .tracking(1.5)
                    .foregroundStyle(Theme.cobalt)
                Spacer()
                Label("不保存原图", systemImage: "lock.shield")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("拍一张，\n看清训练重点。")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("照片只用于本次训练建议，不给体脂率、不诊断体态，也不会写进训练记录。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var photoStage: some View {
        VStack(spacing: 12) {
            photoCanvas

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("从相册选", systemImage: "photo.on.rectangle")
                        .font(AppType.buttonSecondary)
                        .foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Theme.ink.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
                .accessibilityLabel("从相册选择体型照片")
            }
        }
        .card()
    }

    /// A width-driven portrait canvas: the photo is fitted inside instead of
    /// filling and cropping, so full-body shots keep the head and feet.
    private var photoCanvas: some View {
        Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .background {
                Theme.ink.opacity(0.03)
            }
            .overlay {
                if let image {
                    selectedPhoto(image)
                } else {
                    emptyPhoto
                }
            }
            .overlay {
                if isLoadingPhoto {
                    ProgressView("正在读取照片…")
                        .padding(16)
                        .background(
                            Theme.paper,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        image == nil ? Theme.cobalt.opacity(0.35) : Theme.stroke,
                        style: StrokeStyle(
                            lineWidth: image == nil ? 1.2 : 1,
                            dash: image == nil ? [8, 7] : []
                        )
                    )
            }
    }

    private func selectedPhoto(_ image: UIImage) -> some View {
        GeometryReader { proxy in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 24)
                    .opacity(0.30)
                    .clipped()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)

                VStack {
                    HStack {
                        Label("已选择照片", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.onMedia)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.56), in: Capsule())

                        Spacer()

                        Button {
                            withAnimation(Motion.quick) {
                                self.image = nil
                                imageData = nil
                                analysis = nil
                                photoItem = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.onMedia)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.56), in: Circle())
                        }
                        .accessibilityLabel("移除照片")
                    }
                    Spacer()
                }
                .padding(12)
            }
        }
    }

    private var emptyPhoto: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.cobalt.opacity(0.10))
                    .frame(width: 92, height: 92)
                Image(systemName: "figure.stand")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(Theme.cobalt)
            }

            Text("把全身放进画面")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            Text("正面或侧面都可以，镜头与腰同高，别裁掉脚")
                .font(AppType.caption)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            cornerMark.padding(14)
        }
        .overlay(alignment: .topTrailing) {
            cornerMark
                .rotationEffect(.degrees(90))
                .padding(14)
        }
        .overlay(alignment: .bottomLeading) {
            cornerMark
                .rotationEffect(.degrees(-90))
                .padding(14)
        }
        .overlay(alignment: .bottomTrailing) {
            cornerMark
                .rotationEffect(.degrees(180))
                .padding(14)
        }
    }

    private var cornerMark: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 18))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 18, y: 0))
        }
        .stroke(Theme.cobalt.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: 18, height: 18)
    }

    private var guideRow: some View {
        HStack(spacing: 7) {
            guideChip("全身入镜", icon: "figure.stand")
            guideChip("自然站姿", icon: "person.fill")
            guideChip("光线充足", icon: "sun.max.fill")
        }
    }

    private func guideChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Theme.paper, in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle(isOn: $consent) {
                Text("我同意将照片用于本次训练分析")
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
            }
            .tint(Theme.primary)

            Text(store.canUseRemoteAI
                 ? "照片会发送到后端做一次性分析，不保存原图。"
                 : "当前为本地模式：照片只在设备内处理，不联网、不保存。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }

    private var analyzeButton: some View {
        Button {
            analyze()
        } label: {
            if isAnalyzing {
                HStack(spacing: 8) {
                    ProgressView().tint(.black)
                    Text("正在分析体型…")
                }
            } else {
                Label("分析体型并生成训练建议", systemImage: "wand.and.stars")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(imageData == nil || !consent || isAnalyzing)
    }



    private var disclaimer: some View {
        Text("体型照片属于敏感个人信息。请只上传你本人的照片；不要上传他人照片或未成年人照片。分析结果不构成医疗建议。")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private func analyze() {
        guard let imageData, consent else { return }
        guard store.requirePro(.bodyPhoto) else { return }
        isAnalyzing = true

        if store.canUseRemoteAI {
            Task { @MainActor in
                do {
                    let result = try await BodyAnalysisService.analyzeRemote(
                        imageData: imageData,
                        idempotencyKey: analysisKey
                    )
                    finish(result)
                } catch let error as APIError where error.isProRequired {
                    isAnalyzing = false
                    await store.refreshAccess()
                    store.requestPro(.bodyPhoto)
                } catch let error as APIError
                    where error.statusCode == nil || (error.statusCode ?? 0) >= 500 {
                    finish(BodyAnalysisService.analyze(imageData: imageData))
                } catch {
                    isAnalyzing = false
                    message = error.localizedDescription
                    showAlert = true
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            finish(BodyAnalysisService.analyze(imageData: imageData))
        }
    }

    private func finish(_ result: BodyAnalysis) {
        analysis = result
        store.addBodyAnalysis(result)
        isAnalyzing = false
    }

    private func apply(_ picked: UIImage) {
        let prepared = picked.fitWithin(maxDimension: 1600)
        image = prepared
        imageData = prepared.jpegData(compressionQuality: 0.78)
        analysisKey = UUID().uuidString
        analysis = nil
        photoItem = nil
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            photoItem = nil
        }
        do {
            let loaded = try await PhotoLibraryLoader.load(item, maxDimension: 1600)
            image = loaded.image
            imageData = loaded.jpegData
            analysisKey = UUID().uuidString
            analysis = nil
        } catch {
            message = error.localizedDescription
            showAlert = true
        }
    }
}
