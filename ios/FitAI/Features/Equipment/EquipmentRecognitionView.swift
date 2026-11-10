import PhotosUI
import SwiftUI
import UIKit

struct EquipmentRecognitionView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    let onSelect: ((Exercise) -> Void)?
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

    @State var photoItem: PhotosPickerItem?
    @State var selectedImage: UIImage?
    @State var imageData: Data?
    @State var scanKey = UUID().uuidString
    @State var candidates: [EquipmentCandidate] = []
    @State var description = ""
    @State var selectedExercise: Exercise?
    @State var isScanning = false
    @State var showCamera = false
    @State var didAutoStartCamera = false
    @State var recognizedName = ""
    @State var notInLibrary = false
    @State var warning = ""
    @State var scanStatus = "ok"
    @State var equipmentName = ""
    @State var equipmentOptions: [EquipmentMatchOption] = []
    @State var selectedEquipmentSlug: String?
    @State var showAddCustom = false
    @State var didAutoOfferCustom = false
    @State var pendingCustomOffer = false
    @State var customAddedName = ""

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if store.hasProAccess {
                    scanHeaderCard
                    matchesSection
                } else {
                    proLockedCard
                }
            }
            .padding(.horizontal, 20)
            .appPageTopPadding()
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
        .onChange(of: photoItem) { _, _ in
            guard let photoItem else { return }
            Task { @MainActor in
                await load(photoItem)
            }
        }
        .task {
            if store.accessSnapshot == nil {
                await store.refreshAccess()
            }
            guard store.hasProAccess else { return }
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
                hint: "让器械完整进入画面，有品牌/动作标签时一起拍进去，识别更准。",
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("VISION / 器械识别")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("认出器械")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("让器械完整进入画面。识别后可以查看动作，也可以保存到个人器械库。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var proLockedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.onPrimary)
                .frame(width: 42, height: 42)
                .background(Theme.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text("器械识别是 Pro 权益")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            Text("开通 Pro 后可以拍器械照片，自动匹配动作库并加入个人器械库。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button("开通叫练 Pro") {
                store.requestPro(.equipmentScan)
            }
            .buttonStyle(PrimaryButtonStyle())

            Text("识别结果只用于动作匹配，不会保存原始照片。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .editorialCard(accent: Theme.lime)
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
                        Theme.ink.opacity(0.035)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(Theme.cobalt)
                    }
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("照片预览")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                Text(selectedImage == nil ? "还没有照片" : "这张照片")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Text("从最匹配到相似候选")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        showCamera = true
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.cobalt, in: Capsule(style: .continuous))
                    }
                    .buttonStyle(SubtlePressStyle(scale: 0.95))

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("相册", systemImage: "photo")
                            .font(AppType.micro)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.paper, in: Capsule(style: .continuous))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(Theme.stroke, lineWidth: 1)
                            }
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .editorialCard(accent: Theme.lime)
    }

    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("匹配器械")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(candidates.count) 个候选")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            if isScanning {
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.cobalt)
                    Text("正在从动作库匹配…")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 8)
            } else if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !customAddedName.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.cobalt)
                            Text("已加入器械库：\(customAddedName)")
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("可在「我的器械库」查看并关联动作；关联后会进入计划池。")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if scanStatus == "unavailable" {
                        Text("识别服务暂时不可用")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        Text(warning.isEmpty
                             ? "请检查网络后重试；也可以手动搜索动作或添加器械。"
                             : warning)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if imageData != nil {
                            Button {
                                scanKey = UUID().uuidString
                                scan()
                            } label: {
                                Label("重新识别", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    } else if scanStatus == "not_gym_equipment" {
                        Text("这张照片里没有识别到健身器械")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(description.isEmpty
                             ? "请让器械完整进入画面，避免只拍局部或文字。"
                             : description)
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if notInLibrary {
                        Text(equipmentName.isEmpty
                             ? "识别到器械，但动作库暂未收录"
                             : "识别到「\(equipmentName)」，动作库暂未收录")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if !description.isEmpty {
                            Text(description)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            showAddCustom = true
                        } label: {
                            Label("补全器械信息", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text(selectedImage == nil
                             ? "先拍摄或选择一张器械照片。"
                             : "暂未识别到动作库中的器械，可以直接补全并加入个人库。")
                            .font(AppType.callout.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if !description.isEmpty {
                            Text(description)
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if selectedImage != nil && customAddedName.isEmpty {
                        Text("拍摄建议：让器械完整进入画面，并尽量把品牌/动作标签拍清楚；暗光、遮挡或只拍局部都会降低识别率。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            } else {
                if equipmentOptions.count > 1 {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("最可能是")
                            .font(AppType.overline)
                            .tracking(0.8)
                            .foregroundStyle(Theme.tertiaryText)

                        HStack(spacing: 8) {
                            ForEach(equipmentOptions) { option in
                                Button {
                                    selectEquipment(option)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                            .font(AppType.caption.weight(.semibold))
                                        Text("\(Int(option.confidence * 100))%")
                                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundStyle(
                                        selectedEquipmentSlug == option.slug
                                            ? Theme.onPrimary
                                            : Theme.ink
                                    )
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedEquipmentSlug == option.slug
                                            ? Theme.primary
                                            : Theme.paper,
                                        in: Capsule(style: .continuous)
                                    )
                                    .overlay {
                                        Capsule(style: .continuous)
                                            .strokeBorder(Theme.stroke, lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("不确定时点另一个候选，动作会跟着切换。")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else if !equipmentName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.cobalt)
                        Text("识别到 \(equipmentName)")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                resultSection
            }
        }
        .card()
    }



    func selectEquipment(_ option: EquipmentMatchOption) {
        selectedEquipmentSlug = option.slug
        equipmentName = option.name
        candidates = option.candidates
        notInLibrary = false
    }

    var isEquipmentSaved: Bool {
        guard let selectedEquipmentSlug, !equipmentName.isEmpty else { return false }
        return store.equipmentLibrary.contains {
            $0.equipmentType == selectedEquipmentSlug && $0.name == equipmentName
        }
    }

    /// 保存识别到的器械，并把它的可练动作默认全选启用。
    func saveEquipmentAndExercises() {
        guard !isEquipmentSaved else { return }
        let name = equipmentName.isEmpty ? "未命名器械" : equipmentName
        let eligible = candidates.map(\.exercise).filter(\.planEligible)
        let item = store.addEquipment(
            equipmentType: selectedEquipmentSlug,
            name: name,
            category: candidates.first?.exercise.equipment.rawValue,
            photoData: selectedImage?.jpegData(compressionQuality: 0.5) ?? imageData,
            enabledExerciseSlugs: eligible.map(\.slug),
            source: "recognition"
        )
        onSaved?(item)
        recognizedName = name
        customAddedName = eligible.isEmpty
            ? name
            : "\(name) + \(eligible.count) 个动作"
        notInLibrary = false
        description = ""
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        imageData = ImageJPEGNormalizer.data(from: image)
        selectedImage = image
        scanKey = UUID().uuidString
        candidates = []
        description = ""
        photoItem = nil
        recognizedName = ""
        notInLibrary = false
        warning = ""
        scanStatus = "ok"
        equipmentName = ""
        equipmentOptions = []
        selectedEquipmentSlug = nil
        customAddedName = ""
        didAutoOfferCustom = false
        pendingCustomOffer = false
        scan()
    }

    private func apply(_ image: UIImage) {
        selectedImage = image
        imageData = ImageJPEGNormalizer.data(from: image)
        scanKey = UUID().uuidString
        candidates = []
        description = ""
        recognizedName = ""
        notInLibrary = false
        warning = ""
        scanStatus = "ok"
        equipmentName = ""
        equipmentOptions = []
        selectedEquipmentSlug = nil
        customAddedName = ""
        didAutoOfferCustom = false
        pendingCustomOffer = false
    }

    private func scan() {
        guard let data = imageData else { return }
        guard store.requirePro(.equipmentScan) else {
            isScanning = false
            return
        }
        isScanning = true

        Task { @MainActor in
            do {
                let ocrText = await ImageTextRecognizer.recognize(
                    image: selectedImage ?? UIImage(data: data) ?? UIImage()
                )
                let result = try await EquipmentRecognitionService.recognize(
                    imageData: data,
                    preferRemote: store.canUseRemoteAI,
                    ocrText: ocrText,
                    idempotencyKey: scanKey
                )
                candidates = result.candidates
                description = result.description
                recognizedName = result.name
                notInLibrary = result.notInLibrary
                warning = result.warning ?? ""
                scanStatus = result.status
                equipmentOptions = result.equipmentOptions
                if let first = result.equipmentOptions.first {
                    selectedEquipmentSlug = first.slug
                    equipmentName = first.name
                    candidates = first.candidates
                    notInLibrary = false
                } else {
                    selectedEquipmentSlug = nil
                    equipmentName = result.equipmentName ?? ""
                }
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
            } catch EquipmentRecognitionError.proRequired {
                isScanning = false
                await store.refreshAccess()
                store.requestPro(.equipmentScan)
            } catch EquipmentRecognitionError.unavailable(let message) {
                isScanning = false
                warning = message
                description = message
                scanStatus = "unavailable"
            } catch {
                isScanning = false
                warning = error.localizedDescription
                description = error.localizedDescription
                scanStatus = "unavailable"
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
