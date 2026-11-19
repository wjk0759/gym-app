import SwiftUI

/// 发现：认器械、学动作、找训练与饮食方案。
/// 排序原则：核心（器械库/动作库/训练/饮食）在上，工具（识别/点评）在下。
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
                VStack(alignment: .leading, spacing: 16) {
                    equipmentLibraryHero
                    quickGrid
                    toolGrid
                }
                .appPagePadding()
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
                    hint: "拍全身侧面，光线清楚，尽量包含器械和完整动作。照片只用于本次点评。",
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

    // MARK: - Equipment library hero

    private var equipmentLibraryHero: some View {
        NavigationLink(value: TabRoute.equipmentLibrary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("我的器械库")
                            .font(AppType.hero)
                            .foregroundStyle(Theme.ink)
                        Text("\(store.equipmentSnapshot.libraryItems.count) 件 · \(store.equipmentSnapshot.planPoolSlugs.count) 个动作")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Spacer(minLength: 4)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Theme.primary)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.onPrimary)
                    }
                    .frame(width: 66, height: 66)
                }
            }
            .editorialCard(accent: Theme.lime)
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel("打开我的器械库")
    }

    // MARK: - Core entries

    private var quickGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ],
            spacing: 8
        ) {
            NavigationLink(value: TabRoute.equipmentPicker) {
                quickEntry(
                    title: "动作库",
                    icon: "figure.run",
                    accent: Theme.cobalt,
                    foreground: Theme.onAccent
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            Button {
                Haptics.tap()
                showTrainingLibrary = true
            } label: {
                quickEntry(
                    title: "训练方案",
                    icon: "calendar",
                    accent: Theme.lime
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            Button {
                Haptics.tap()
                showDietLibrary = true
            } label: {
                quickEntry(
                    title: "饮食方案",
                    icon: "fork.knife",
                    accent: Theme.primary
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))

            Button {
                Haptics.tap()
                if store.requirePro(.bodyPhoto) {
                    showBodyAnalysis = true
                }
            } label: {
                quickEntry(
                    title: "体型分析",
                    icon: "figure.stand",
                    accent: Theme.ink,
                    foreground: Theme.onAccent
                )
            }
            .buttonStyle(CardPressStyle(scale: 0.97))
        }
    }

    private func quickEntry(
        title: String,
        icon: String,
        accent: Color,
        foreground: Color = Theme.onPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(foreground)
                    .frame(width: 30, height: 30)
                    .background(accent, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(title)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - Tools

    private var toolGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("工具")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.leading, 2)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                Button {
                    Haptics.tap()
                    if store.requirePro(.equipmentScan) {
                        showEquipmentScan = true
                    }
                } label: {
                    toolCard(
                        title: "拍照识别器械",
                        icon: "camera.viewfinder"
                    )
                }
                .buttonStyle(CardPressStyle(scale: 0.97))

                Menu {
                    Button {
                        Haptics.tap()
                        if store.requirePro(.coachVision) {
                            showActionCamera = true
                        }
                    } label: {
                        Label("拍一张", systemImage: "camera.fill")
                    }

                    Button {
                        Haptics.tap()
                        if store.requirePro(.videoReview) {
                            showVideoReview = true
                        }
                    } label: {
                        Label("选视频", systemImage: "video.fill")
                    }
                } label: {
                    toolCard(
                        title: "动作点评",
                        icon: "camera.metering.center.weighted"
                    )
                }
            }
        }
    }

    private func toolCard(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 32, height: 32)
                .background(
                    Theme.cobalt,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            Text(title)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
