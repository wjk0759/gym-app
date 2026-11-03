import AVKit
import Charts
import Foundation
import SwiftUI
import UIKit

struct EquipmentItemDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("pinnedEquipmentIDs") var pinnedEquipmentIDsRaw = ""

    private let itemID: UUID?
    private let previewExercise: Exercise?

    @State var showDelete = false
    @State var showCoach = false
    @State var officialVideoURL: URL?
    @State var detailTab: DetailTab = .points

    enum DetailTab: String, CaseIterable, Identifiable {
        case points
        case muscles
        case equipment

        var id: String { rawValue }

        var title: String {
            switch self {
            case .points: return "注意事项"
            case .muscles: return "目标肌群"
            case .equipment: return "所需器械"
            }
        }

        var symbol: String {
            switch self {
            case .points: return "checklist"
            case .muscles: return "figure.strengthtraining.functional"
            case .equipment: return "dumbbell.fill"
            }
        }
    }
    @State var statsPeriod: EquipmentStatsPeriod = .ninetyDays
    @State var statsMetric: EquipmentStatsMetric = .volume
    @State var customStart = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State var customEnd = Date()
    @State var showCustomRange = false

    init(itemID: UUID) {
        self.itemID = itemID
        self.previewExercise = nil
    }

    init(exercise: Exercise) {
        self.itemID = nil
        self.previewExercise = exercise
    }

    var item: EquipmentItem? {
        if let previewExercise {
            return EquipmentItem(
                name: previewExercise.nameZH,
                slug: previewExercise.slug,
                muscle: previewExercise.muscle,
                equipment: previewExercise.equipment,
                videoURL: previewExercise.videoURL?.absoluteString,
                notes: ""
            )
        }
        guard let itemID else { return nil }
        return store.equipmentLibrary.first { $0.id == itemID }
    }

    var isPreview: Bool {
        previewExercise != nil
    }

    var videoURL: URL? {
        officialVideoURL ?? item?.videoURL.flatMap(URL.init(string:))
    }

    var pinnedIDs: Set<String> {
        Set(pinnedEquipmentIDsRaw.split(separator: ",").map(String.init))
    }

    var customRangeInvalid: Bool {
        statsPeriod == .custom && customStart > customEnd
    }

    var customRangeLabel: String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: customStart)
            == calendar.component(.year, from: customEnd)
        let startStyle: Date.FormatStyle = .dateTime.year().month(.defaultDigits).day()
        let endStyle: Date.FormatStyle = sameYear
            ? .dateTime.month(.defaultDigits).day()
            : .dateTime.year().month(.defaultDigits).day()
        return "\(customStart.formatted(startStyle)) – \(customEnd.formatted(endStyle))"
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                AppScrollView {
                    if let item {
                        content(for: item, proxy: proxy)
                    } else {
                        EmptyStateView(
                            icon: "dumbbell",
                            title: "器械不存在",
                            message: "它可能已经被删除。"
                        )
                        .padding(20)
                    }
                }
            }
            .background(AppBackground())
            .navigationTitle(isPreview ? "动作详情" : "器械详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                guard AppConfig.exerciseVideosEnabled, let slug = item?.slug else { return }
                if let url = try? await ExerciseVideoService().officialURL(slug: slug) {
                    officialVideoURL = url
                }
            }
            .confirmationDialog(
                "从器械库删除？",
                isPresented: $showDelete,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let itemID {
                        store.removeEquipment(itemID)
                    }
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后，下次生成计划不会再优先使用这件器械。")
            }
            .sheet(isPresented: $showCoach) {
                CoachChatView()
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func content(for item: EquipmentItem, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 16) {
            quickActions(for: item, proxy: proxy)

            // 教学视频素材未上线，入口先隐藏；播放器代码保留在 EquipmentDetailView+Media.swift。
            if AppConfig.exerciseVideosEnabled {
                videoContent(for: item)
            }

            hero(for: item)
            detailTabPicker

            Group {
                switch detailTab {
                case .points:
                    VStack(spacing: 12) {
                        detailSection(
                            index: "01",
                            title: "动作要点",
                            lead: "下面的要点来自动作库和你的器械备注。"
                        ) {
                            pointsContent(for: item)
                        }

                        detailSection(
                            index: "02",
                            title: "动作轨迹",
                            lead: "先用轨迹示意建立动作路径，再在训练中把速度放慢。"
                        ) {
                            motionBoard(for: item)
                        }

                        detailSection(
                            index: "03",
                            title: "多角度示范",
                            lead: "示范素材准备中。先用要点确认起始位置和身体角度。"
                        ) {
                            angleGrid(for: item)
                        }
                    }
                case .muscles:
                    detailSection(
                        index: "01",
                        title: "目标肌群",
                        lead: "主要训练 \(item.muscle?.label ?? "全身")，协同稳定由 \(supportMuscles(for: item).joined(separator: "、")) 参与。"
                    ) {
                        muscleContent(for: item)
                    }
                case .equipment:
                    equipmentInfoSection(for: item)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))

            detailSection(
                index: "04",
                title: "训练数据",
                lead: statsLead(for: item)
            ) {
                statsContent(for: item)
            }
            .id("stats")

            coachCard(for: item)

            if !isPreview {
                Button(role: .destructive) {
                    showDelete = true
                } label: {
                    Text("从器械库删除")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Theme.danger.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.danger.opacity(0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Text(AppConfig.exerciseVideosEnabled
                 ? "出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。教学视频和示范素材由官方动作库提供。"
                 : "出现关节刺痛、麻木或肿胀时请停止动作并咨询专业人士。示范素材由官方动作库提供。")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 6)
        }
        .padding(20)
        .padding(.bottom, 24)
    }

    private var detailTabPicker: some View {
        HStack(spacing: 6) {
            ForEach(DetailTab.allCases) { tab in
                let selected = detailTab == tab
                Button {
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        detailTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 10, weight: .bold))
                        Text(tab.title)
                            .font(AppType.caption.weight(.bold))
                    }
                    .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selected ? Theme.cobalt : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(SubtlePressStyle(scale: 0.96))
            }
        }
        .padding(4)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

}
