import SwiftUI

extension SettingsView {
    // MARK: - AI 与连接

    var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 服务")
                        .font(AppType.headline)
                    Text(store.hasProAccess
                         ? (store.useRemoteAI ? "远程模式 · 调用后端模型" : "本地模式 · 规则模板")
                         : "免费额度 · 每周 3 条 AI 教练")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Toggle("", isOn: remoteBinding)
                    .labelsHidden()
                    .tint(Theme.primary)
                    .disabled(!store.hasProAccess)
                    .opacity(store.hasProAccess ? 1 : 0.45)
            }

            Text(store.hasProAccess
                 ? (store.useRemoteAI
                    ? "Pro 已解锁：生成计划、教练对话和视觉识别会请求 DeepSeek/后端；失败时自动回退本地。"
                    : "已开通 Pro，但当前关闭了远程 AI。打开开关后可使用 DeepSeek。")
                 : "免费用户每周 3 条 AI 教练；Pro 解锁不限条数和完整 AI 能力。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

#if DEBUG
            // 测试/诊断入口：仅 Debug 显示；Release 隐藏，不要删除。
            // 后续真机联调、后端切换和健康检查仍会用到。
            Text("Debug 构建不会绕过 Pro；请用服务端测试账号验证 Pro。")
                .font(AppType.caption)
                .foregroundStyle(Theme.tertiaryText)

            Text(AppConfig.apiBaseURL.absoluteString)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Button("测试连接") {
                testConnection()
            }
            .buttonStyle(SecondaryButtonStyle())
#endif
        }
        .card()
    }

    var remoteBinding: Binding<Bool> {
        Binding(
            get: { store.useRemoteAI },
            set: {
                store.useRemoteAI = $0
                store.persist()
            }
        )
    }

    /// 仅 Debug 显示入口；Release 不调用，保留用于联调。
    func testConnection() {
        Task { @MainActor in
            do {
                let status = try await BackendHealthService.status()
                serviceModel = status.llm ?? ""
                message = status.status == "ok"
                    ? "后端连接成功 · \(status.llm ?? "模型未配置")"
                    : "能连上后端，但健康检查返回异常。"
            } catch {
                message = "连接失败：\(error.localizedDescription)"
            }
            showMessage = true
        }
    }
}
