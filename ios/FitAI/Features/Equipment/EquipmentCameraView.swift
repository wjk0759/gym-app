import AVFoundation
import PhotosUI
import SwiftUI
import UIKit

/// 器械识别的拍摄入口：相机优先，同时保留相册和退出按钮。
/// 拍完/选完照片后立即交给识别页，不在这里展示识别结果。
struct EquipmentCameraView: View {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    @StateObject private var camera = EquipmentCameraController()
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isReady {
                EquipmentCameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    Text(camera.errorMessage ?? "正在启动相机…")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            VStack {
                HStack(spacing: 12) {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.42), in: Circle())
                    }
                    .accessibilityLabel("退出拍摄")

                    Spacer()

                    Text("拍摄器械")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.42), in: Circle())
                    }
                    .accessibilityLabel("从相册选择")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 12) {
                    Text("让器械完整进入画面，避免只拍到局部或边缘。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    Button {
                        camera.capture { image in
                            onImage(image)
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.9), lineWidth: 4)
                                .frame(width: 74, height: 74)
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(!camera.isReady)
                    .opacity(camera.isReady ? 1 : 0.4)
                    .accessibilityLabel("拍照")

                    if camera.errorMessage != nil {
                        Text("也可以点右上角相册，选择已有照片。")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.bottom, 30)
            }

            if isLoadingPhoto {
                ProgressView("正在读取照片…")
                    .padding(18)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: photoItem?.itemIdentifier) { _, _ in
            guard let photoItem else { return }
            Task { @MainActor in
                await loadPhoto(photoItem)
            }
        }
    }

    @MainActor
    private func loadPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        onImage(image)
    }
}

private final class EquipmentCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.fitai.equipment.camera")
    private var configured = false
    private var captureCompletion: ((UIImage) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configure()
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "相机权限未开启，请从相册选择器械照片。"
                    }
                }
            }
        default:
            errorMessage = "相机权限未开启，请从相册选择器械照片。"
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capture(completion: @escaping (UIImage) -> Void) {
        guard session.isRunning else { return }
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    private func configure() {
        sessionQueue.async { [weak self] in
            guard let self, !self.configured else { return }
            self.configured = true

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input),
                self.session.canAddOutput(self.output) else {
                DispatchQueue.main.async {
                    self.errorMessage = "当前设备没有可用相机，请从相册选择器械照片。"
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.session.addInput(input)
            self.session.addOutput(self.output)
            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async {
                self.isReady = true
            }
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        let completion = captureCompletion
        captureCompletion = nil
        DispatchQueue.main.async {
            completion?(image)
        }
    }
}

private struct EquipmentCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
