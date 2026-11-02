import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct SwipeDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTap: () -> Void
    let onDelete: () -> Void
    let content: Content

    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 84

    init(
        isOpen: Bool,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isOpen = isOpen
        self.onOpen = onOpen
        self.onClose = onClose
        self.onTap = onTap
        self.onDelete = onDelete
        self.content = content()
    }

    private var offset: CGFloat {
        if dragOffset != 0 {
            return dragOffset
        }
        return isOpen ? -actionWidth : 0
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Text("删除")
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.danger.opacity(0.14))
            }
            .buttonStyle(.plain)
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(isOpen)

            content
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    if isOpen {
                        onClose()
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                return
                            }
                            let base = isOpen ? -actionWidth : 0
                            dragOffset = min(0, max(-actionWidth, base + value.translation.width))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                dragOffset = 0
                                return
                            }
                            let base = isOpen ? -actionWidth : 0
                            let projected = base + value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                dragOffset = 0
                            }
                            if projected < -actionWidth * 0.45 {
                                onOpen()
                            } else {
                                onClose()
                            }
                        }
                )
        }
        .clipped()
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isOpen)
        .accessibilityAction(named: Text("删除")) {
            onDelete()
        }
    }
}

struct AddEquipmentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedExercise: Exercise?
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showExercisePicker = false
    @State private var message = ""
    @State private var showAlert = false

    init(initialPhotoData: Data? = nil) {
        _photoData = State(initialValue: initialPhotoData)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("器械名称")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：高位下拉", text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 30 {
                                    name = String(value.prefix(30))
                                }
                            }
                            .padding(12)
                            .background(
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("对应动作")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedExercise?.nameZH ?? "选择动作")
                                        .font(AppType.callout)
                                        .foregroundStyle(Theme.ink)
                                    Text(selectedExercise.map {
                                        "\($0.muscle.label) · \($0.equipment.label)"
                                    } ?? "用于匹配计划与教学视频")
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(AppType.caption)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注（选填）")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：调节座位高度在 3 档", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .onChange(of: notes) { _, value in
                                if value.count > 120 {
                                    notes = String(value.prefix(120))
                                }
                            }
                            .padding(12)
                            .background(
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    photoCard

                    Button("保存到器械库") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("添加器械")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(equipment: store.profile.availableEquipment) { exercise in
                    selectedExercise = exercise
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        name = exercise.nameZH
                    }
                }
            }
            .onChange(of: photoItem) { _, _ in
                guard let item = photoItem else { return }
                Task { @MainActor in
                    await load(item)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    title: "拍摄器械",
                    hint: "让器械完整进入画面，避免只拍到局部或边缘。",
                    onImage: { picked in
                        photoData = picked.jpegData(compressionQuality: 0.7)
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

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("器械照片（选填）")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            if let data = photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("拍照") { showCamera = true }
                    .buttonStyle(SecondaryButtonStyle())
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("相册")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.cobalt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.cobalt.opacity(0.10))
                        )
                }
            }
        }
        .card()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "先填一个器械名称，或选择对应动作。"
            showAlert = true
            return
        }

        let exercise = selectedExercise
        let item = EquipmentItem(
            name: trimmed,
            slug: exercise?.slug,
            muscle: exercise?.muscle,
            equipment: exercise?.equipment,
            videoURL: exercise?.videoURL?.absoluteString,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData
        )
        store.addEquipment(item)
        dismiss()
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        photoData = image.jpegData(compressionQuality: 0.7)
        photoItem = nil
    }
}

struct EquipmentThumbnail: View {
    let itemID: UUID
    let data: Data

    @State private var image: UIImage?
    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: itemID) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        let key = "\(itemID.uuidString)-\(data.count)" as NSString
        if let cached = Self.cache.object(forKey: key) {
            image = cached
            return
        }
        let payload = data
        let decoded = await Task.detached(priority: .utility) {
            Self.downsample(payload, maxPixel: 140)
        }.value
        guard let decoded else { return }
        Self.cache.setObject(decoded, forKey: key)
        image = decoded
    }

    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
