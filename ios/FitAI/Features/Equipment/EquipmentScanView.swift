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
    @State private var searchText = ""
    @State private var savedSlugs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    libraryShortcut

                    imageArea

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

                    if !candidates.isEmpty {
                        resultSection
                    }

                    manualSearch
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("器械识别")
            .navigationBarTitleDisplayMode(.large)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍一下器械\n马上知道怎么用")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("识别后会给出动作要领与替代方案。看不清就换一个角度，或者手动搜索。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var libraryShortcut: some View {
        NavigationLink {
            EquipmentLibraryView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的器械库")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("已录入 \(store.equipmentLibrary.count) 件 · 查看教学视频")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        }
        .buttonStyle(.plain)
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
        .card()
    }

    private var manualSearch: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "找不到？手动搜索", subtitle: "输入器械或动作名称")

            TextField("例如：高位下拉、腿举", text: $searchText)
                .padding(12)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            ForEach(Array(ExerciseLibrary.search(searchText).prefix(5))) { exercise in
                if !searchText.isEmpty {
                    Button {
                        selectedExercise = exercise
                    } label: {
                        HStack {
                            Text(exercise.nameZH)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(exercise.equipment.label)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
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

        if store.useRemoteAI {
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
            .background(Theme.background.ignoresSafeArea())
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
