import PhotosUI
import SwiftUI
import UIKit

struct BodyPhotoAnalysisView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
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
                .padding(20)
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
                Label("AI 体型分析", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
                Spacer()
                Label("不保存原图", systemImage: "lock.shield")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text("拍一张，\n看清训练重点。")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("照片只用于本次训练建议，不给体脂率、不诊断体态，也不会写进训练记录。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var photoStage: some View {
        VStack(spacing: 12) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

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
                } else {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.accent.opacity(0.10))
                                .frame(width: 92, height: 92)
                            Image(systemName: "figure.stand")
                                .font(.system(size: 54, weight: .light))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("把全身放进画面")
                            .font(.headline)
                            .foregroundStyle(Theme.primaryText)
                        Text("正面或侧面都可以，镜头与腰同高，别裁掉脚")
                            .font(.caption)
                            .foregroundStyle(Theme.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(
                        LinearGradient(
                            colors: [Theme.surfaceStrong, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                Theme.accent.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.2, dash: [8, 7])
                            )
                    )
                    .overlay(alignment: .topLeading) {
                        cornerMark
                            .padding(14)
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

                if isLoadingPhoto {
                    ProgressView("正在读取照片…")
                        .padding(16)
                        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.accent.opacity(0.22), lineWidth: 0.8)
                        )
                }
                .accessibilityLabel("从相册选择体型照片")
            }
        }
        .card()
    }

    private var cornerMark: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 18))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 18, y: 0))
        }
        .stroke(Theme.accent.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Theme.surfaceStrong, in: Capsule())
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Toggle(isOn: $consent) {
                Text("我同意将照片用于本次训练分析")
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
            }
            .tint(Theme.accent)

            Text(store.canUseRemoteAI
                 ? "照片会发送到后端做一次性分析，不保存原图。"
                 : "当前为本地模式：照片只在设备内处理，不联网、不保存。")
                .font(.caption2)
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

    private func resultCard(_ analysis: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("分析结果")
                    .font(.headline)
                Spacer()
                Text("参考置信度 \(Int(analysis.confidence * 100))%")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }

            Text(analysis.summary)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("建议训练重点")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 8) {
                    ForEach(analysis.focusAreas) { muscle in
                        TagChip(text: muscle.label, selected: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(analysis.recommendations, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Text(analysis.disclaimer)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.applyBodyAnalysis(analysis)
                dismiss()
            } label: {
                Label(
                    analysis.appliedToPlan ? "已应用到当前计划" : "应用到训练计划",
                    systemImage: "wand.and.stars"
                )
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(analysis.appliedToPlan)

            Button {
                store.openCoachAfterBodyAnalysis(analysis)
                dismiss()
            } label: {
                Label("去 AI 教练继续", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private var disclaimer: some View {
        Text("体型照片属于敏感个人信息。请只上传你本人的照片；不要上传他人照片或未成年人照片。分析结果不构成医疗建议。")
            .font(.caption2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: 14)
    }

    private func analyze() {
        guard let imageData, consent else { return }
        isAnalyzing = true

        if store.canUseRemoteAI {
            Task { @MainActor in
                do {
                    let result = try await APIClient.shared.analyzeBody(imageData: imageData)
                    finish(result)
                } catch {
                    isAnalyzing = false
                    message = "这次照片分析没有完成，请检查网络后重试。照片没有被保存。"
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
            analysis = nil
        } catch {
            message = error.localizedDescription
            showAlert = true
        }
    }
}
