import PhotosUI
import SwiftUI

/// Tappable avatar with camera/album entry and upload state.
/// Kept separate from ProfileView so the profile page stays a layout file.
struct AvatarEditorButton: View {
    @Environment(AuthStore.self) private var auth

    let initial: String
    var size: CGFloat = 52

    @State private var showActions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Button {
            Haptics.tap()
            showActions = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                avatar
                cameraBadge
            }
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
        .accessibilityLabel(auth.avatarURL == nil ? "添加头像" : "修改头像")
        .confirmationDialog("头像", isPresented: $showActions, titleVisibility: .visible) {
            Button("拍照") {
                showCamera = true
            }
            Button("从相册选择") {
                showPhotoPicker = true
            }
            if auth.avatarURL != nil {
                Button("移除头像", role: .destructive) {
                    Task { await removeAvatar() }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItem,
            matching: .images
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            PhotoCaptureView(
                title: "拍摄头像",
                hint: "让脸部完整进入画面，光线均匀。",
                onImage: { image in
                    showCamera = false
                    Task { await upload(image) }
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        .alert("头像", isPresented: $showError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后再试。")
        }
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            if let url = auth.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }

            if isUploading {
                Circle()
                    .fill(.black.opacity(0.38))
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.inkSolid, lineWidth: 2))
    }

    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Theme.primary)
            Text(String(initial.prefix(1)))
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(Theme.onPrimary)
        }
    }

    private var cameraBadge: some View {
        Image(systemName: "camera.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Theme.onPrimary)
            .frame(width: 18, height: 18)
            .background(Theme.ink, in: Circle())
            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 1.5))
            .offset(x: 2, y: 2)
            .accessibilityHidden(true)
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploading = true
        defer {
            isUploading = false
            photoItem = nil
        }
        do {
            let data = try await PhotoLibraryLoader.loadAvatar(item)
            try await auth.uploadAvatar(data)
            Haptics.success()
        } catch {
            present(error)
        }
    }

    private func upload(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }
        do {
            let data = try PhotoLibraryLoader.prepareAvatar(image)
            try await auth.uploadAvatar(data)
            Haptics.success()
        } catch {
            present(error)
        }
    }

    private func removeAvatar() async {
        isUploading = true
        defer { isUploading = false }
        do {
            try await auth.removeAvatar()
            Haptics.success()
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        showError = true
    }
}
