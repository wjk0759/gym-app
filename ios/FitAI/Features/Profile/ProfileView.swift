import Foundation
import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    @State private var showPaywall = false
    @State private var showBodyAnalysis = false
    @State private var showBodyCheckIn = false

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: AppLayout.sectionSpacing) {
                    sectionLabel("账户与会员")
                        .padding(.top, 0)
                    accountCard

                    sectionLabel("身体与目标")
                    metricsCard
                    goalCard

                    sectionLabel("训练工具")
                    bodyAnalysisCard
                    equipmentLibraryCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle("我的")
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
        }
    }

    // MARK: - 账户与会员

    private var accountCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ProfileEditView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.18))
                            .frame(width: 54, height: 54)
                        Text(String(store.profile.nickname.prefix(1)))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.profile.nickname)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text("\(store.profile.goalType.label) · \(store.profile.experience.label) · 每周 \(store.profile.weeklyDays) 练")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Text("编辑资料")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(Theme.stroke)
                .padding(.vertical, 13)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("练途 Pro")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text("AI 计划、教练与器械识别")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Spacer()

                    Text("开通 / 管理")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .card()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppType.micro)
            .tracking(1.2)
            .foregroundStyle(Theme.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.horizontal, 2)
    }

    private var metricsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                metric("体重", String(format: "%.1f kg", store.profile.weightKG))
                metric("BMI", String(format: "%.1f", store.profile.bmi) + " · " + store.profile.bmiLabel)
            }
            HStack(spacing: 12) {
                metric("体脂", String(format: "%.1f%%", store.profile.bodyFatPCT))
                metric("腰围", String(format: "%.0f cm", store.profile.waistCM))
            }
            HStack(spacing: 12) {
                metric("臂围", String(format: "%.1f cm", store.profile.armCM))
                metric("大腿围", String(format: "%.1f cm", store.profile.thighCM))
            }
            HStack(spacing: 12) {
                metric("累计训练", "\(store.sessions.count) 次")
                metric("总容量", "\(Int(store.totalVolume)) kg")
            }
            Button("记录今日身体数据") {
                showBodyCheckIn = true
            }
            .buttonStyle(SecondaryButtonStyle())
            if let latest = store.latestBodyMetric {
                Text("最近记录 \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前目标")
                    .font(.headline)
                Spacer()
                Text(store.profile.goalType.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
            }

            if store.profile.goalType != .endurance {
                HStack {
                    Text("目标体重")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(store.profile.targetWeightKG, specifier: "%.1f") kg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                }
            }

            if let targetWaist = store.profile.targetWaistCM {
                HStack {
                    Text("目标腰围")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(String(format: "%.0f cm", targetWaist))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                }
            }

            if let targetBodyFat = store.profile.targetBodyFatPCT {
                HStack {
                    Text("目标体脂")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(String(format: "%.1f%%", targetBodyFat))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                }
            }

            HStack {
                Text("目标日期")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(store.profile.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
            }

            Text("目标仅作方向，不追求极端速度。减重建议不超过 0.5kg/周。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    // MARK: - 训练工具

    private var bodyAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("体型照片分析")
                        .font(.headline)
                    Text("拍一张照片，获取训练重点建议")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "figure.stand")
                    .foregroundStyle(Theme.accent)
            }

            if let latest = store.bodyAnalyses.first {
                Text(latest.summary)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    ForEach(latest.focusAreas) { muscle in
                        TagChip(text: muscle.label, selected: true)
                    }
                }
            } else {
                Text("照片只用于本次分析，不写入训练记录。分析结果仅作训练重点参考。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Button("拍照分析体型") {
                showBodyAnalysis = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
        .sheet(isPresented: $showBodyAnalysis) {
            BodyPhotoAnalysisView()
        }
    }

    private var equipmentLibraryCard: some View {
        NavigationLink {
            EquipmentLibraryView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的器械库")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("已录入 \(store.equipmentLibrary.count) 件 · 教学视频与计划")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}
