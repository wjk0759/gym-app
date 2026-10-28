import SwiftUI

/// 发现：认器械、学动作、找训练与饮食方案。把原来分散在“器械”Tab 的能力收进一个入口。
struct DiscoverView: View {
    @Environment(AppStore.self) private var store

    @State private var showEquipmentScan = false
    @State private var showBodyAnalysis = false
    @State private var showTrainingLibrary = false
    @State private var showDietLibrary = false
    @State private var showActionCamera = false
    @State private var showVideoReview = false
    @State private var selectedDiet: DietChoice?

    private struct DietChoice: Identifiable {
        let id: String
        let label: String
    }

    private struct DietCard: Identifiable {
        let id: String
        let label: String
        let tagline: String
        let icon: String
        let color: Color
    }

    private let dietCards: [DietCard] = [
        DietCard(id: "balanced", label: "均衡饮食", tagline: "最稳，长期坚持", icon: "circle.grid.cross", color: Theme.accent),
        DietCard(id: "high_protein", label: "高蛋白", tagline: "力量训练优先", icon: "bolt.heart.fill", color: Theme.blue),
        DietCard(id: "carb_cycle", label: "碳循环", tagline: "训练日高碳", icon: "arrow.triangle.2.circlepath", color: Theme.warning),
        DietCard(id: "low_carb", label: "低碳", tagline: "控制主食", icon: "leaf.fill", color: Color(red: 0.44, green: 0.78, blue: 0.35))
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    equipmentHero
                    quickGrid
                    actionReviewCard

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "训练方案", subtitle: "先选分化，再让教练排动作。")
                        ForEach(SplitType.allCases) { split in
                            Button {
                                Haptics.tap()
                                showTrainingLibrary = true
                            } label: {
                                splitRow(split)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "饮食策略", subtitle: "不是少吃，是吃对。")
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 9),
                                GridItem(.flexible(), spacing: 9)
                            ],
                            spacing: 9
                        ) {
                            ForEach(dietCards) { item in
                                Button {
                                    Haptics.select()
                                    selectedDiet = DietChoice(id: item.id, label: item.label)
                                } label: {
                                    dietCard(item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    NavigationLink {
                        EquipmentLibraryView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("我的器械库")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("已录入 \(store.equipmentLibrary.count) 件 · 查看动作与训练数据")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .card(padding: 13)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $selectedDiet) { choice in
                WeekDietPlanView(
                    initialStrategy: choice.id,
                    forceStrategy: true
                )
            }
            .fullScreenCover(isPresented: $showActionCamera) {
                PhotoCaptureView(
                    title: "动作点评",
                    hint: "拍全身侧面，光线清楚，尽量包含器械和完整动作。照片只用于本次点评。",
                    onImage: { image in
                        store.sendCoachPhoto(image)
                        showActionCamera = false
                        store.selectedTab = 2
                    },
                    onCancel: {
                        showActionCamera = false
                    }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("发现")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("认器械，学动作，找方案。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var equipmentHero: some View {
        Button {
            Haptics.tap()
            showEquipmentScan = true
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.88), Theme.accentDeep.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 92, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.14))
                    .offset(x: 22, y: 24)

                VStack(alignment: .leading, spacing: 9) {
                    Text("不认识器械？")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.86))
                    Text("拍给我。识别后直接告诉你练什么、怎么练。")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                    Label("拍器械", systemImage: "camera.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.72), in: Capsule())
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var quickGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 9),
                GridItem(.flexible(), spacing: 9)
            ],
            spacing: 9
        ) {
            NavigationLink {
                EquipmentPickerView()
            } label: {
                actionLabel("动作教程", subtitle: "按肌群和器械学", icon: "figure.run", color: Theme.blue)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                showTrainingLibrary = true
            } label: {
                actionLabel("训练方案", subtitle: "全身 / 推拉腿 / 五分", icon: "calendar", color: Theme.accent)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                showDietLibrary = true
            } label: {
                actionLabel("饮食方案", subtitle: "均衡 / 高蛋白 / 碳循环", icon: "fork.knife", color: Theme.warning)
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                showBodyAnalysis = true
            } label: {
                actionLabel("体型分析", subtitle: "拍照看训练重点", icon: "figure.stand", color: Theme.danger)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionLabel(
        _ title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 115, alignment: .topLeading)
        .padding(12)
        .background(Theme.cardSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.8)
        )
    }

    private var actionReviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "camera.metering.center.weighted")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("动作点评")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text("拍一张，或发一段视频，让教练指出下一组最该改的一点")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    showActionCamera = true
                } label: {
                    Label("拍一张", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Theme.accent.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    showVideoReview = true
                } label: {
                    Label("选视频", systemImage: "video.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Theme.surfaceStrong, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 13)
    }

    private func splitRow(_ split: SplitType) -> some View {
        HStack(spacing: 11) {
            Image(systemName: split == .one ? "figure.strengthtraining.functional" : (split == .three ? "arrow.triangle.2.circlepath" : "square.grid.2x2.fill"))
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(split.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    if store.profile.split == split {
                        Text("当前")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                Text(split.detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card(padding: 12)
    }

    private func dietCard(_ item: DietCard) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: item.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.color)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            Text(item.label)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
            Text(item.tagline)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            LinearGradient(
                colors: [item.color.opacity(0.10), Theme.cardSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(item.color.opacity(0.14), lineWidth: 0.8)
        )
    }
}
