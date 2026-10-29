import Foundation
import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    @State private var showPaywall = false
    @State private var showBodyAnalysis = false
    @State private var showBodyCheckIn = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                bodyMetricsSection
                trainingStatsSection
                goalSection
                bodyAnalysisSection
                equipmentSection
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .tint(Theme.accentText)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton()
                }
            }
            .sheet(isPresented: $showBodyCheckIn) {
                BodyCheckInSheet(manual: true)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showBodyAnalysis) {
                BodyPhotoAnalysisView()
            }
        }
    }

    // MARK: - 账户与会员

    private var accountSection: some View {
        Section {
            NavigationLink {
                ProfileEditView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentText.opacity(0.14))
                            .frame(width: 52, height: 52)
                        Text(String(store.profile.nickname.prefix(1)))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.accentText)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.profile.nickname)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(
                            "\(store.profile.goalType.label) · \(store.profile.experience.label) · 每周 \(store.profile.weeklyDays) 练"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    }
                }
            }

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("练途 Pro")
                            .foregroundStyle(.primary)
                        Text("AI 计划、教练与器械识别")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(store.isPro ? "已开通" : "开通 / 管理")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentText)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("账户与会员")
        } footer: {
            Text("资料仅用于生成训练计划和教练对话。")
        }
    }

    // MARK: - 身体数据

    private var bodyMetricsSection: some View {
        Section {
            LabeledContent("体重", value: String(format: "%.1f kg", store.profile.weightKG))
            LabeledContent(
                "BMI",
                value: String(format: "%.1f", store.profile.bmi) + " · " + store.profile.bmiLabel
            )
            LabeledContent("体脂", value: String(format: "%.1f%%", store.profile.bodyFatPCT))
            LabeledContent("腰围", value: String(format: "%.0f cm", store.profile.waistCM))
            LabeledContent("臂围", value: String(format: "%.1f cm", store.profile.armCM))
            LabeledContent("大腿围", value: String(format: "%.1f cm", store.profile.thighCM))

            Button("记录今日身体数据") {
                showBodyCheckIn = true
            }
            .buttonStyle(.borderless)
        } header: {
            Text("身体数据")
        } footer: {
            if let latest = store.latestBodyMetric {
                Text("最近记录 \(latest.date.formatted(date: .abbreviated, time: .omitted))")
            }
        }
    }

    private var trainingStatsSection: some View {
        Section {
            LabeledContent("累计训练", value: "\(store.sessions.count) 次")
            LabeledContent("总容量", value: "\(Int(store.totalVolume)) kg")
        } header: {
            Text("训练统计")
        }
    }

    // MARK: - 目标

    private var goalSection: some View {
        Section {
            LabeledContent("当前目标", value: store.profile.goalType.label)

            if store.profile.goalType != .endurance {
                LabeledContent(
                    "目标体重",
                    value: String(format: "%.1f kg", store.profile.targetWeightKG)
                )
            }

            if let targetWaist = store.profile.targetWaistCM {
                LabeledContent(
                    "目标腰围",
                    value: String(format: "%.0f cm", targetWaist)
                )
            }

            if let targetBodyFat = store.profile.targetBodyFatPCT {
                LabeledContent(
                    "目标体脂",
                    value: String(format: "%.1f%%", targetBodyFat)
                )
            }

            LabeledContent(
                "目标日期",
                value: store.profile.targetDate.formatted(date: .abbreviated, time: .omitted)
            )
        } header: {
            Text("目标")
        } footer: {
            Text("目标仅作方向，不追求极端速度。减重建议不超过 0.5kg/周。")
        }
    }

    // MARK: - 训练工具

    private var bodyAnalysisSection: some View {
        Section {
            if let latest = store.bodyAnalyses.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(latest.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(latest.focusAreas) { muscle in
                                TagChip(text: muscle.label, selected: true)
                            }
                        }
                    }
                }
            }

            Button {
                showBodyAnalysis = true
            } label: {
                Label("拍照分析体型", systemImage: "camera")
            }
            .buttonStyle(.borderless)
        } header: {
            Text("体型照片分析")
        } footer: {
            Text("照片只用于本次分析，不写入训练记录。分析结果仅作训练重点参考。")
        }
    }

    private var equipmentSection: some View {
        Section {
            NavigationLink {
                EquipmentLibraryView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(Theme.accentText)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("我的器械库")
                            .foregroundStyle(.primary)
                        Text("已录入 \(store.equipmentLibrary.count) 件 · 教学视频与计划")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("训练工具")
        } footer: {
            Text("生成计划时会优先使用器械库中已启用的器械。")
        }
    }
}
