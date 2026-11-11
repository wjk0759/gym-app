import PhotosUI
import SwiftUI
import UIKit

/// 器械照片：拍照 / 相册 / 远端图预览，添加和编辑共用。
struct EquipmentPhotoCard: View {
    @Binding var photoData: Data?
    var remotePhotoURL: String? = nil
    var title: String = "器械照片（选填）"

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false

    init(
        photoData: Binding<Data?>,
        remotePhotoURL: String? = nil,
        title: String = "器械照片（选填）"
    ) {
        _photoData = photoData
        self.remotePhotoURL = remotePhotoURL
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            preview

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
        .onChange(of: photoItem) { _, _ in
            guard let photoItem else { return }
            Task { @MainActor in
                await load(photoItem)
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
    }

    @ViewBuilder
    private var preview: some View {
        if let data = photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let url = AppConfig.resolveMediaURL(remotePhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    failurePlaceholder
                default:
                    remotePlaceholder
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var remotePlaceholder: some View {
        ZStack {
            Theme.ink.opacity(0.035)
            ProgressView()
                .tint(Theme.tertiaryText)
        }
    }

    private var failurePlaceholder: some View {
        ZStack {
            Theme.ink.opacity(0.035)
            Image(systemName: "photo")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
        }
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
