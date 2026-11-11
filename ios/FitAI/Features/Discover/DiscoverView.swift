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
                    header
                    equipmentLibraryHero
                    quickGrid
                    toolGrid
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, AppLayout.tabBarContentInset)
            }
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("EXPLORE / 发现")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("找点新练法")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("认器械，学动作，找方案。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Equipment library hero

    private var equipmentLibraryHero: some View {
        NavigationLink(value: TabRoute.equipmentLibrary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("MY EQUIPMENT / 我的器械库")
                            .font(AppType.overline)
                            .tracking(1.2)
                            .foregroundStyle(Theme.cobalt)

                        Text("把器械变成计划")
                            .font(AppType.hero)
                            .tracking(-0.6)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("已录入 \(store.equipmentLibrary.count) 件 · 计划池 \(store.planPoolSlugs.count) 个动作")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.primary)
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(Theme.onPrimary)
                    }
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(2))
                    .padding(.top, 4)
                }

                HStack(spacing: 6) {
                    heroPill("覆盖 \(store.planPoolBodyParts.count) 个部位", accent: true)
                    heroPill(store.strictEquipmentMode ? "只用我的器械" : "优先我的器械")
                }
            }
            .editorialCard(accent: Theme.lime)
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityLabel("打开我的器械库")
    }

    private func heroPill(_ text: String, accent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(accent ? Theme.ink : Theme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                accent ? Theme.lime.opacity(0.75) : Theme.paper,
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        accent ? Theme.ink.opacity(0.16) : Theme.stroke,
                        lineWidth: 1
                    )
            }
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
                    subtitle: "按训练类型和部位学",
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
                    subtitle: "全身 / 推拉腿 / 五分",
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
                    subtitle: "均衡 / 高蛋白 / 碳循环",
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
                    subtitle: "拍照看训练重点",
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
        subtitle: String,
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

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
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
                        subtitle: "加入器械库",
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
                        subtitle: "拍照 / 视频",
                        icon: "camera.metering.center.weighted"
                    )
                }
            }
        }
    }

    private func toolCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 32, height: 32)
                .background(
                    Theme.cobalt,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

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
