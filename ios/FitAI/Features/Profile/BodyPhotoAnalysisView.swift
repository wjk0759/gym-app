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
    @State private var consent = false
    @State private var showCamera = false
    @State private var message = ""
    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    header
                    photoCard
                    consentCard

                    Button {
                        analyze()
                    } label: {
                        if isAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView().tint(.black)
                                Text("正在分析…")
                            }
                        } else {
                            Text("分析体型并生成训练建议")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(imageData == nil || !consent || isAnalyzing)

                    if let analysis {
                        resultCard(analysis)
                    }

                    disclaimer
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("体型照片分析")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onChange(of: photoItem?.itemIdentifier) { _, _ in
                guard let item = photoItem else { return }
                Task { @MainActor in
                    await load(item)
                }
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
            .alert("提示", isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍一张全身或半身照\n让 AI 给训练重点建议")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("分析只给训练重点，不判断体脂率、不诊断体态。照片默认只在本次分析中使用，不写入训练记录。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoCard: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 230)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            self.image = nil
                            imageData = nil
                            analysis = nil
                            photoItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .padding(10)
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Theme.accent)
                    Text("拍照或选择一张照片")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text("正面或侧面，光线充足，避免遮挡")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                )
            }

            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍照", systemImage: "camera")
                }
                .buttonStyle(SecondaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相册", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent.opacity(0.10))
                        )
                }
            }
        }
        .card()
    }

    private var consentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $consent) {
                Text("我同意将照片用于本次训练分析")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .tint(Theme.accent)

            Text(store.useRemoteAI && store.isPro
                 ? "当前为远程 AI 模式：照片会发送到后端做一次性分析，不保存原图。"
                 : "当前为本地模式：照片只在设备内存中参与分析，不联网、不保存。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
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
                .foregroundStyle(.white)
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

        if store.useRemoteAI && store.isPro {
            Task { @MainActor in
                do {
                    let result = try await APIClient.shared.analyzeBody(imageData: imageData)
                    finish(result)
                } catch {
                    finish(BodyAnalysisService.analyze(imageData: imageData))
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
        image = picked
        imageData = picked.jpegData(compressionQuality: 0.7)
        analysis = nil
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let picked = UIImage(data: data) else {
            return
        }
        imageData = data
        image = picked
        analysis = nil
    }
}
