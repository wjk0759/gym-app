import SwiftUI

/// 发现：认器械、学动作、找训练与饮食方案。
/// The page keeps the capability map from the old tab, but reads as an
/// editorial index: one scan hero, four entries, then training and diet shelves.
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
                    equipmentHero
                    quickGrid
                    actionReviewCard
                    splitSection
                    equipmentLibraryLink
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
            .appTabDestinations()
            .sheet(isPresented: $showEquipmentScan) {
                EquipmentRecognitionView(
                    onSaved: { item in
                        store.toast = "已加入个人动作库：\(item.name)"
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

    // MARK: - Equipment hero

    private var equipmentHero: some View {
        Button {
            Haptics.tap()
            if store.requirePro(.equipmentScan) {
                showEquipmentScan = true
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("AI 器械识别")
                        .font(AppType.overline)
                        .tracking(1.2)
                        .foregroundStyle(Theme.cobalt)

                    Text("拍一下，\n就知道练什么")
                        .font(AppType.hero)
                        .tracking(-0.6)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Label("拍器械", systemImage: "camera.fill")
                        .font(AppType.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Theme.cobalt, in: Capsule(style: .continuous))
                        .padding(.top, 2)
                }

                Spacer(minLength: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.primary)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(Theme.onPrimary)
                }
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(2))
                .padding(.top, 4)
            }
            .editorialCard(accent: Theme.lime)
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }

    // MARK: - Quick entries

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
                    title: "动作教程",
                    subtitle: "按肌群和器械学",
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

    // MARK: - Review

    private var actionReviewCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("动作点评")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    if store.requirePro(.coachVision) {
                        showActionCamera = true
                    }
                } label: {
                    Label("拍一张", systemImage: "camera.fill")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Theme.cobalt,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))

                Button {
                    Haptics.tap()
                    if store.requirePro(.videoReview) {
                        showVideoReview = true
                    }
                } label: {
                    Label("选视频", systemImage: "video.fill")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Theme.paper,
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))
            }
        }
        .card()
    }

    // MARK: - Training splits

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionTitle(title: "训练方案", subtitle: "先选分化，再让教练排动作。")

            VStack(spacing: 0) {
                ForEach(SplitType.allCases) { split in
                    Button {
                        Haptics.tap()
                        showTrainingLibrary = true
                    } label: {
                        splitRow(split)
                    }
                    .buttonStyle(.plain)

                    if split != SplitType.allCases.last {
                        InkDivider()
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
    }

    private func splitRow(_ split: SplitType) -> some View {
        HStack(spacing: 11) {
            Image(systemName: splitIcon(split))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 32, height: 32)
                .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(split.title)
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)

                    if store.profile.split == split {
                        Text("当前")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.onPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primary, in: Capsule(style: .continuous))
                    }
                }

                Text(split.detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func splitIcon(_ split: SplitType) -> String {
        switch split {
        case .one: return "figure.strengthtraining.functional"
        case .three: return "arrow.triangle.2.circlepath"
        case .five: return "square.grid.2x2.fill"
        }
    }

    // MARK: - Equipment library

    private var equipmentLibraryLink: some View {
        NavigationLink(value: TabRoute.equipmentLibrary) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("我的器械库")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("已录入 \(store.equipmentLibrary.count) 件 · 查看动作与训练数据")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
    }
}
