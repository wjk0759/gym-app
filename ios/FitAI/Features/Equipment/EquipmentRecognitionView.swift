import PhotosUI
import SwiftUI
import UIKit

struct EquipmentRecognitionView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let onSelect: ((Exercise) -> Void)?
    private let onSaved: ((EquipmentItem) -> Void)?
    private let onRecognized: ((EquipmentScanResult) -> Void)?
    private let isModal: Bool

    init(
        isModal: Bool = false,
        onSelect: ((Exercise) -> Void)? = nil,
        onSaved: ((EquipmentItem) -> Void)? = nil,
        onRecognized: ((EquipmentScanResult) -> Void)? = nil
    ) {
        self.isModal = isModal
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
    @State private var didAutoOfferCustom = false
    @State private var pendingCustomOffer = false
    @State private var customAddedName = ""

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
        .navigationBarBackButtonHidden(isModal)
        .toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: photoItem) { _, _ in
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
                return
            }
            offerCustomIfNeeded()
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
                photo: selectedImage,
                onAdd: { name, muscle, equipment in
                    let item = EquipmentItem(
                        name: name,
                        slug: nil,
                        muscle: muscle,
                        equipment: equipment,
                        videoURL: nil,
                        notes: "拍照识别未收录，手动添加",
                        photoData: selectedImage?.jpegData(compressionQuality: 0.7) ?? imageData,
                        source: "recognition"
                    )
                    store.addEquipment(item)
                    onSaved?(item)
                    recognizedName = name
                    customAddedName = name
                    notInLibrary = false
                    description = ""
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
                    .foregroundStyle(Theme.primaryText)
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
                    .foregroundStyle(Theme.primaryText)
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
                    if !customAddedName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.accent)
                            Text("已加入个人动作库：\(customAddedName)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("可在「我的器械库」查看；生成计划仍只使用动作库内已收录的标准动作。")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(selectedImage == nil
                             ? "先拍摄或选择一张器械照片。"
                             : "暂未识别到动作库中的器械，可以直接补全并加入个人库。")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primaryText)
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
                                Label("补全器械信息", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if selectedImage != nil && customAddedName.isEmpty {
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
                                .foregroundStyle(Theme.primaryText)
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

            Button {
                showAddCustom = true
            } label: {
                Label("都不是？补全器械信息", systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Theme.surfaceStrong, in: Capsule())
            }
            .buttonStyle(.plain)
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
        photoItem = nil
        recognizedName = ""
        notInLibrary = false
        customAddedName = ""
        didAutoOfferCustom = false
        pendingCustomOffer = false
        scan()
    }

    private func apply(_ image: UIImage) {
        selectedImage = image
        imageData = image.jpegData(compressionQuality: 0.8)
        candidates = []
        description = ""
        recognizedName = ""
        notInLibrary = false
        customAddedName = ""
        didAutoOfferCustom = false
        pendingCustomOffer = false
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
            customAddedName = ""
            onRecognized?(result)
            isScanning = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if result.notInLibrary && !didAutoOfferCustom {
                didAutoOfferCustom = true
                if showCamera {
                    pendingCustomOffer = true
                } else {
                    showAddCustom = true
                }
            }
        }
    }

    private func offerCustomIfNeeded() {
        guard pendingCustomOffer else { return }
        pendingCustomOffer = false
        showAddCustom = true
    }
}

/// 拍照识别到「动作库未收录」的器械时，自动弹出的补全卡片。
private struct CustomExerciseAddSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialName: String
    let photo: UIImage?
    let onAdd: (String, MuscleGroup, Equipment) -> Void

    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment: Equipment = .machine
    @FocusState private var nameFocused: Bool

    private let muscleColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    private let equipmentColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 0.8)
                            )
                    }

                    nameCard
                    muscleCard
                    equipmentCard

                    Button {
                        add()
                    } label: {
                        Label("加入个人动作库", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("补充器械信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = initialName
                }
                nameFocused = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                Text("AI 识别到了动作库外器械")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)

            Text("补全后加入你的个人动作库")
                .font(.system(size: 25, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("AI 已预填识别名称。确认名称、训练肌群和器械类型后，加入你的个人器械库。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("动作名称")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            TextField("例如：髋外展机", text: $name)
                .focused($nameFocused)
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onChange(of: name) { _, value in
                    if value.count > 40 {
                        name = String(value.prefix(40))
                    }
                }
        }
        .card(padding: 14)
    }

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("主要训练肌群")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: muscleColumns, spacing: 7) {
                ForEach(MuscleGroup.allCases) { group in
                    selectionChip(
                        title: group.label,
                        selected: muscle == group
                    ) {
                        muscle = group
                        Haptics.select()
                    }
                }
            }
        }
        .card(padding: 14)
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("器械类型")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: equipmentColumns, spacing: 7) {
                ForEach(Equipment.allCases) { item in
                    selectionChip(
                        title: item.label,
                        selected: equipment == item
                    ) {
                        equipment = item
                        Haptics.select()
                    }
                }
            }
        }
        .card(padding: 14)
    }

    private func selectionChip(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selected ? Theme.accent : Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(selected ? Theme.accent : Color.clear, lineWidth: 0.8)
                )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.96))
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, muscle, equipment)
        dismiss()
    }
}
