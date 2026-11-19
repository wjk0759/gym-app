import SwiftUI

struct DiscoverView: View {
    @Environment(AppStore.self) private var store

    @Binding var navigationPath: NavigationPath

    @State private var showEquipmentScan = false
    @State private var showBodyAnalysis = false
    @State private var showTrainingLibrary = false
    @State private var showDietLibrary = false
    @State private var showActionCamera = false
    @State private var showVideoReview = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AppScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 0) {
                        NavigationLink(value: TabRoute.equipmentLibrary) {
                            row(
                                title: "我的器械库",
                                detail: "\(store.equipmentSnapshot.libraryItems.count) 件 · \(store.equipmentSnapshot.planPoolSlugs.count) 个动作",
                                icon: "square.stack.3d.up"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("打开我的器械库")
                    }
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }

                    section("训练") {
                        NavigationLink(value: TabRoute.equipmentPicker) {
                            row(title: "动作库", icon: "figure.run")
                        }
                        .buttonStyle(.plain)
                        rowDivider
                        rowButton(title: "训练方案", icon: "calendar") {
                            showTrainingLibrary = true
                        }
                        rowDivider
                        rowButton(title: "饮食方案", icon: "fork.knife") {
                            showDietLibrary = true
                        }
                        rowDivider
                        rowButton(title: "体型分析", icon: "figure.stand") {
                            if store.requirePro(.bodyPhoto) {
                                showBodyAnalysis = true
                            }
                        }
                    }

                    section("工具") {
                        rowButton(title: "拍照识别器械", icon: "camera.viewfinder") {
                            if store.requirePro(.equipmentScan) {
                                showEquipmentScan = true
                            }
                        }
                        rowDivider
                        Menu {
                            Button {
                                if store.requirePro(.coachVision) {
                                    showActionCamera = true
                                }
                            } label: {
                                Label("拍一张", systemImage: "camera")
                            }
                            Button {
                                if store.requirePro(.videoReview) {
                                    showVideoReview = true
                                }
                            } label: {
                                Label("选视频", systemImage: "video")
                            }
                        } label: {
                            row(title: "动作点评", icon: "camera.metering.center.weighted")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .appPageTopPadding()
            }
            .appTabBarClearance()
            .background(AppBackground())
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
            .appTabDestinations()
            .sheet(isPresented: $showEquipmentScan) {
                EquipmentRecognitionView(
                    onSaved: { item in
                        store.toast = "已加入器械库：\(item.name)"
                    },
                    onRecognized: { result in
                        store.coachEquipmentResult = result
                    }
                )
            }
            .sheet(isPresented: $showBodyAnalysis) {
                BodyPhotoAnalysisView()
            }
            .sheet(isPresented: $showTrainingLibrary) {
                TrainingLibraryView()
            }
            .sheet(isPresented: $showDietLibrary) {
                DietLibraryView()
            }
            .sheet(isPresented: $showVideoReview) {
                VideoReviewView()
            }
            .fullScreenCover(isPresented: $showActionCamera) {
                PhotoCaptureView(
                    title: "动作点评",
                    hint: "拍全身侧面，光线清楚。",
                    onImage: { image in
                        if let data = image.jpegData(compressionQuality: 0.75) {
                            store.queueCoachAttachment(data)
                        }
                        showActionCamera = false
                    },
                    onCancel: {
                        showActionCamera = false
                    }
                )
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 52)
    }

    private func rowButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            row(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func row(
        title: String,
        detail: String? = nil,
        icon: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppType.body)
                    .foregroundStyle(Theme.ink)
                if let detail {
                    Text(detail)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
