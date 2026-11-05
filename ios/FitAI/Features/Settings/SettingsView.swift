import SwiftUI
import UIKit

struct SettingsToolbarButton: View {
    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("设置")
    }
}

struct SettingsView: View {
    enum ServiceState {
        case checking
        case online
        case offline
    }

    @Environment(AppStore.self) var store
    @Environment(AuthStore.self) var auth
    @Environment(WeatherStore.self) var weather
    @Environment(\.openURL) var openURL

    @State var serviceState: ServiceState = .checking
    @State var serviceModel = ""
    @State var reminderDate = Date()
    @State var showLogout = false
    @State var showMessage = false
    @State var message = ""
    @State var legalDocument: LegalDocumentKind?
    @State var showExport = false
    @State var showPasswordSettings = false
    @State var showBodyCheckIn = false
    @State var showDeleteAccount = false
    @State var showAgentMemory = false
    @State var showWeatherDetail = false

    var body: some View {
        AppScrollView {
            VStack(spacing: AppLayout.sectionSpacing) {
                header
                accountCard

#if DEBUG
                // 调试用服务状态：Release 隐藏，不要删除。
                sectionLabel("服务状态")
                serviceCard
#endif

                sectionLabel("训练设置")
                reminderCard
                bodyCheckInCard
                healthCard
                preferenceCard

                sectionLabel("天气与出行")
                weatherCard

#if DEBUG
                sectionLabel("AI 与连接")
                aiCard
#endif

                sectionLabel("数据与隐私")
                privacyCard

                sectionLabel("账号操作")
                logoutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: syncReminder)
        .task {
#if DEBUG
            await checkService()
#endif
        }
        .alert("提示", isPresented: $showMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
        .confirmationDialog(
            "退出当前账号？",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后本机训练数据会保留，下次登录可继续使用。")
        }
        .confirmationDialog(
            "注销账号？",
            isPresented: $showDeleteAccount,
            titleVisibility: .visible
        ) {
            Button("申请注销账号", role: .destructive) {
                Task {
                    do {
                        try await auth.deleteAccount()
                        store.resetAll()
                        ProgressPhotoStore.deleteAll()
                    } catch {
                        message = "注销失败：\(error.localizedDescription)"
                        showMessage = true
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("账号会进入 15 天冷静期，期间可联系 \(LegalMeta.contactEmail) 恢复；冷静期结束后删除或匿名化账号及云端数据。本机当前账号数据、进展照片会清除；系统备份需你手动删除。")
        }
        .sheet(isPresented: $showExport) {
            DataExportView()
        }
        .sheet(item: $legalDocument) { kind in
            LegalDocumentView(kind: kind)
        }
        .sheet(isPresented: $showPasswordSettings) {
            PasswordSettingsView()
        }
        .sheet(isPresented: $showBodyCheckIn) {
            BodyCheckInSheet(manual: true)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAgentMemory) {
            AgentMemoryView()
        }
        .sheet(isPresented: $showWeatherDetail) {
            WeatherDetailSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
    }
}
