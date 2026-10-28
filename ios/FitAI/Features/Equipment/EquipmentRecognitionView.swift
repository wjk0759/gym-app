import PhotosUI
import SwiftUI
import UIKit

struct EquipmentRecognitionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let onSelect: ((Exercise) -> Void)?
    private let onSaved: ((EquipmentItem) -> Void)?
    private let onRecognized: ((EquipmentScanResult) -> Void)?

    init(
        onSelect: ((Exercise) -> Void)? = nil,
        onSaved: ((EquipmentItem) -> Void)? = nil,
        onRecognized: ((EquipmentScanResult) -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onSaved = onSaved
        self.onRecognized = onRecognized
    }

    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var imageData: Data?
    @State private var candidates: [EquipmentCandidate] = []
    @State private var description = ""
    @State private var selectedExercise: Exercise?
    @State private var isScanning = false
    @State private var showCamera = false
    @State private var didAutoStartCamera = false
    @State private var savedSlugs: Set<String> = []
    @State private var recognizedName = ""
    @State private var notInLibrary = false
    @State private var showAddCustom = false

    var body: some View {
        AppScrollView {
            VStack(spacing: 16) {
                scanHeaderCard
                matchesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("器械识别")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("关闭器械识别")
            }
        }
        .onChange(of: photoItem?.itemIdentifier) { _, _ in
            guard let photoItem else { return }
            Task { @MainActor in
                await load(photoItem)
            }
        }
        .task {
            guard !didAutoStartCamera, selectedImage == nil else { return }
            didAutoStartCamera = true
            showCamera = true
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            // 用户退出拍摄且没有照片时，不进入空的结果页。
            if selectedImage == nil {
                dismiss()
            }
        }) {
            PhotoCaptureView(
                title: "拍摄器械",
                hint: "让器械完整进入画面，避免只拍到局部或边缘。",
                onImage: { image in
                    apply(image)
                    showCamera = false
                    scan()
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        .sheet(item: $selectedExercise) { exercise in
            EquipmentItemDetailView(exercise: exercise)
        }
        .sheet(isPresented: $showAddCustom) {
            CustomExerciseAddSheet(
                initialName: recognizedName,
                onAdd: { name, muscle, equipment in
                    let item = EquipmentItem(
                        name: name,
                        slug: nil,
                        muscle: muscle,
                        equipment: equipment,
                        videoURL: nil,
                        notes: "拍照识别未收录，手动添加",
                        photoData: selectedImage?.jpegData(compressionQuality: 0.5) ?? imageData,
                        source: "recognition"
                    )
                    store.addEquipment(item)
                    onSaved?(item)
                }
            )
            .presentationDetents([.medium])
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

                    if !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if notInLibrary {
                        Button {
                            showAddCustom = true
                        } label: {
                            Text("添加到个人动作库")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

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

                        if let onSelect {
                            Button {
                                onSelect(candidate.exercise)
                                dismiss()
                            } label: {
                                Label("加入已选", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        }

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
        let item = EquipmentItem(
            name: candidate.exercise.nameZH,
            slug: candidate.exercise.slug,
            muscle: candidate.exercise.muscle,
            equipment: candidate.exercise.equipment,
            videoURL: candidate.exercise.videoURL?.absoluteString,
            notes: "来自拍照识别",
            photoData: selectedImage?.jpegData(compressionQuality: 0.5) ?? imageData
        )
        store.addEquipment(item)
        onSaved?(item)
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
        description = ""
        recognizedName = ""
        notInLibrary = false
        scan()
    }

    private func apply(_ image: UIImage) {
        selectedImage = image
        imageData = image.jpegData(compressionQuality: 0.8)
        candidates = []
        description = ""
        recognizedName = ""
        notInLibrary = false
    }

    private func scan() {
        guard let data = imageData else { return }
        isScanning = true

        Task { @MainActor in
            let result = await EquipmentRecognitionService.recognize(
                imageData: data,
                preferRemote: store.canUseRemoteAI
            )
            candidates = result.candidates
            description = result.description
            recognizedName = result.name
            notInLibrary = result.notInLibrary
            onRecognized?(result)
            isScanning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

/// 拍照识别到「动作库未收录」的器械时，用户自定义添加的个人动作表单。
private struct CustomExerciseAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    let onAdd: (String, MuscleGroup, Equipment) -> Void

    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: Equipment = .machine

    var body: some View {
        NavigationStack {
            Form {
                Section("动作名称") {
                    TextField("例如：髋外展机", text: $name)
                }
                Section("训练肌群") {
                    Picker("肌群", selection: $muscle) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.label).tag(group)
                        }
                    }
                }
                Section("器械类型") {
                    Picker("器械", selection: $equipment) {
                        ForEach(Equipment.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                }
            }
            .navigationTitle("添加到个人动作库")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if name.isEmpty { name = initialName }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed, muscle, equipment)
                        dismiss()
                    }
                }
            }
        }
    }
}
