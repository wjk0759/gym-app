import Foundation
import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    @State private var showBodyAnalysis = false
    @State private var showBodyCheckIn = false
    @State private var showFocusAreas = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    accountCard
                    metricsCard
                    goalCard
                    focusAreasCard
                    bodyAnalysisCard
                    equipmentLibraryCard
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .sheet(isPresented: $showBodyCheckIn) {
                BodyCheckInSheet(manual: true)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFocusAreas) {
                FocusAreasSheet()
            }
            .sheet(isPresented: $showBodyAnalysis) {
                BodyPhotoAnalysisView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("PROFILE / 我的")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("我的档案")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("训练、身体和目标，都在这里。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            NavigationLink {
                ProfileEditView()
            } label: {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary)
                        Circle()
                            .strokeBorder(Theme.inkSolid, lineWidth: 2)
                        Text(String(store.profile.nickname.prefix(1)))
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(Theme.onPrimary)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.profile.nickname)
                            .font(AppType.title)
                            .tracking(-0.3)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(store.profile.goalType.label) · \(store.profile.experience.label) · 每周 \(store.profile.weeklyDays) 练")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            InkDivider()

            Button {
                Haptics.tap()
                store.requestPro(.general)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.onPrimary)
                        .frame(width: 30, height: 30)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("叫练 Pro")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        if let expires = store.accessSnapshot?.proExpiresAt {
                            Text("有效期至 \(expires.formatted(date: .abbreviated, time: .omitted))")
                                .font(AppType.micro)
                                .foregroundStyle(Theme.tertiaryText)
                        } else if !store.hasProAccess {
                            Text("解锁 App 内全部功能")
                                .font(AppType.micro)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }

                    Spacer(minLength: 4)

                    Text(store.hasProAccess ? "查看" : "升级")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .editorialCard(accent: Theme.lime)
    }

    // MARK: - Body metrics

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("身体数据")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 4)

                if let latest = store.latestBodyMetric {
                    Text("最近 \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            HStack(spacing: 8) {
                bodyStat(
                    value: String(format: "%.1f", store.profile.weightKG),
                    label: "体重 · kg"
                )
                bodyStat(
                    value: String(format: "%.1f", store.profile.bodyFatPCT),
                    label: "体脂 · %"
                )
                bodyStat(
                    value: String(format: "%.0f", store.profile.waistCM),
                    label: "腰围 · cm"
                )
            }

            HStack(spacing: 8) {
                bodyStat(
                    value: String(format: "%.1f", store.profile.bmi),
                    label: "BMI · \(store.profile.bmiLabel)"
                )
                bodyStat(
                    value: String(format: "%.1f", store.profile.armCM),
                    label: "臂围 · cm"
                )
                bodyStat(
                    value: String(format: "%.1f", store.profile.thighCM),
                    label: "大腿围 · cm"
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.cobalt)
                Text("累计 \(store.sessions.count) 次训练 · 总容量 \(Int(store.totalVolume)) kg")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                Spacer(minLength: 0)
            }

            Button("记录今日身体数据") {
                Haptics.tap()
                showBodyCheckIn = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 2)
        }
        .card()
    }

    private func bodyStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }

    // MARK: - Goal

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("当前目标")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                Spacer(minLength: 4)

                Text(store.profile.goalType.label)
                    .font(AppType.micro)
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary, in: Capsule(style: .continuous))
            }

            if store.profile.goalType != .endurance {
                goalRow(
                    "目标体重",
                    value: String(format: "%.1f kg", store.profile.targetWeightKG)
                )
            }

            if let targetWaist = store.profile.targetWaistCM {
                goalRow("目标腰围", value: String(format: "%.0f cm", targetWaist))
            }

            if let targetBodyFat = store.profile.targetBodyFatPCT {
                goalRow("目标体脂", value: String(format: "%.1f%%", targetBodyFat))
            }

            goalRow(
                "目标日期",
                value: store.profile.targetDate.formatted(date: .abbreviated, time: .omitted)
            )

            Text("目标仅作方向，不追求极端速度。减重建议不超过 0.5kg/周。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
        .card()
    }

    private func goalRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppType.callout)
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
    }

    // MARK: - Focus areas

    private var focusAreasCard: some View {
        let areas = store.planFocusAreas

        return Button {
            Haptics.tap()
            showFocusAreas = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("训练重点")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(
                        areas.isEmpty
                            ? "全身均衡"
                            : BodyFocusArea.displayOrder
                                .filter(areas.contains)
                                .map(\.label)
                                .joined(separator: "、")
                    )
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
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

    // MARK: - Body analysis

    private var bodyAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 34, height: 34)
                    .background(Theme.coral, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("体型照片分析")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                }

                Spacer(minLength: 0)
            }

            if let latest = store.bodyAnalyses.first {
                Text(latest.summary)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ForEach(latest.focusAreas) { muscle in
                        TagChip(text: muscle.label, selected: true)
                    }
                }
            } else {
                Text("照片只用于本次分析，不写入训练记录。分析结果仅作训练重点参考。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("拍照分析体型") {
                Haptics.tap()
                if store.requirePro(.bodyPhoto) {
                    showBodyAnalysis = true
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    // MARK: - Equipment library

    private var equipmentLibraryCard: some View {
        NavigationLink {
            EquipmentLibraryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 36, height: 36)
                    .background(Theme.cobalt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("我的器械库")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("已录入 \(store.equipmentLibrary.count) 件 · \(AppConfig.exerciseVideosEnabled ? "教学视频与计划" : "动作与计划")")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
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
