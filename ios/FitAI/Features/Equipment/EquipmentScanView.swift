import PhotosUI
import AVKit
import SwiftUI
import UIKit

struct EquipmentScanView: View {
    @Environment(AppStore.self) private var store

    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageData: Data?
    @State private var candidates: [EquipmentCandidate] = []
    @State private var selectedExercise: Exercise?
    @State private var isScanning = false
    @State private var showCamera = false
    @State private var savedSlugs: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scanHeaderCard
                quickActions

                Button {
                    scan()
                } label: {
                    if isScanning {
                        HStack(spacing: 8) {
                            ProgressView().tint(.black)
                            Text("识别中…")
                        }
                    } else {
                        Text("识别器械")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(imageData == nil || isScanning)

                matchesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("器械识别")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem?.itemIdentifier) { _, _ in
            guard let item = photoItem else { return }
            Task { @MainActor in
                await load(item)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                apply(image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
    }

    private var scanHeaderCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Theme.surfaceStrong
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("照片识别")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
                Text("识别你的器械")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("从最匹配到相似候选")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: 12) {
                    Button("重新拍照") {
                        showCamera = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("从相册选择")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .card()
    }

    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("匹配器械")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(candidates.count) 个候选")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.accent)
                    Text("正在从动作库匹配…")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 8)
            } else if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedImage == nil
                         ? "先拍摄或选择一张器械照片。"
                         : "暂未识别到动作库中的器械，请拍摄完整器械。")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if selectedImage != nil {
                        Text("拍摄建议：让器械完整进入画面，避免只露出边缘；暗光、遮挡或只拍局部都会降低识别率。")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            } else {
                resultSection
            }
        }
        .card()
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            NavigationLink {
                EquipmentSearchView()
            } label: {
                quickActionTile("magnifyingglass", "搜索")
            }
            .buttonStyle(.plain)

            Button {
                showCamera = true
            } label: {
                quickActionTile("camera", "拍照")
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $photoItem, matching: .images) {
                quickActionTile("photo", "相册")
            }
        }
    }

    private func quickActionTile(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍一下器械\n马上知道怎么用")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("搜索动作库、拍一张照片，或从相册选择。识别后会给出动作要领与替代方案。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var imageArea: some View {
        if let selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button {
                        self.selectedImage = nil
                        imageData = nil
                        candidates = []
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
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.accent)
                Text("拍一张器械照片")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text("支持常见固定器械、绳索、杠铃与哑铃")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        Theme.stroke,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                    )
            )
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "识别结果",
                subtitle: candidates.first.map {
                    $0.confidence < 0.6 ? "置信度较低，请从候选中确认" : "点击查看动作要领"
                }
            )

            ForEach(candidates) { candidate in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(candidate.exercise.nameZH)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(candidate.exercise.muscle.label) · \(candidate.exercise.equipment.label)")
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Text("\(Int(candidate.confidence * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(candidate.confidence >= 0.6 ? Theme.accent : Theme.warning)
                    }

                    ProgressView(value: candidate.confidence)
                        .tint(candidate.confidence >= 0.6 ? Theme.accent : Theme.warning)

                    if candidate.confidence < 0.6 {
                        Text("需要确认：这张图可能不是这个器械")
                            .font(.caption2)
                            .foregroundStyle(Theme.warning)
                    }

                    HStack {
                        Button {
                            saveToLibrary(candidate)
                        } label: {
                            Label(
                                isSaved(candidate) ? "已保存" : "保存到器械库",
                                systemImage: isSaved(candidate) ? "checkmark.circle.fill" : "plus.circle"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSaved(candidate) ? Theme.tertiaryText : Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaved(candidate))

                        Spacer()

                        Button {
                            selectedExercise = candidate.exercise
                        } label: {
                            Text("查看动作 ›")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceStrong)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedExercise = candidate.exercise
                }
            }
        }
    }

    private func isSaved(_ candidate: EquipmentCandidate) -> Bool {
        savedSlugs.contains(candidate.exercise.slug)
            || store.equipmentLibrary.contains { $0.slug == candidate.exercise.slug }
    }

    private func saveToLibrary(_ candidate: EquipmentCandidate) {
        guard !isSaved(candidate) else { return }
        store.addEquipment(
            EquipmentItem(
                name: candidate.exercise.nameZH,
                slug: candidate.exercise.slug,
                muscle: candidate.exercise.muscle,
                equipment: candidate.exercise.equipment,
                videoURL: candidate.exercise.videoURL?.absoluteString,
                notes: "来自拍照识别",
                photoData: selectedImage?.jpegData(compressionQuality: 0.5) ?? imageData
            )
        )
        savedSlugs.insert(candidate.exercise.slug)
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        imageData = data
        selectedImage = image
        candidates = []
    }

    private func apply(_ image: UIImage) {
        selectedImage = image
        imageData = image.jpegData(compressionQuality: 0.8)
        candidates = []
    }

    private func scan() {
        guard let data = imageData else { return }
        isScanning = true

        if store.useRemoteAI && store.isPro {
            Task { @MainActor in
                do {
                    let remote = try await APIClient.shared.scanEquipment(imageData: data)
                    candidates = remote.isEmpty
                        ? EquipmentService.recognize(imageData: data)
                        : remote
                } catch {
                    candidates = EquipmentService.recognize(imageData: data)
                }
                isScanning = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            candidates = EquipmentService.recognize(imageData: data)
            isScanning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let exercise: Exercise

    @ViewBuilder
    private var videoSection: some View {
        if let videoURL = exercise.videoURL {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(Theme.accent)
                    Text("教学视频")
                        .font(.headline)
                }
                Text("还没有配置视频。把授权素材上传后，在 videos.json 里填上动作 slug 与播放地址即可。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .card()
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.nameZH)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("动作要领")
                            .font(.headline)
                        Text(exercise.instructions)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card()

                    videoSection
                    Button {
                        store.sendChat("\(exercise.nameZH)怎么用？需要注意什么？")
                        dismiss()
                    } label: {
                        Label("问教练这个动作", systemImage: "bubble.left")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("如果动作过程中出现关节刺痛、麻木或肿胀，请停止并咨询医生。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("动作详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
