import SwiftUI

extension SettingsView {
    // MARK: - AI 与连接

    var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 服务")
                        .font(AppType.headline)
                    Text(store.useRemoteAI ? "远程模式 · 调用后端模型" : "本地模式 · 规则模板")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Toggle("", isOn: remoteBinding)
                    .labelsHidden()
                    .tint(Theme.primary)
            }

            Text(store.hasProAccess
                 ? (store.useRemoteAI
                    ? "Pro 已解锁：生成计划、教练对话和视觉识别会请求 DeepSeek/后端；失败时自动回退本地。"
                    : "已开通 Pro，但当前关闭了远程 AI。打开开关后可使用 DeepSeek。")
                 : "AI 能力为 Pro 会员权益。未开通时使用本地规则建议；开通后可调用 DeepSeek 的 AI 私人健身教练。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

#if DEBUG
            Text("Debug 构建不会绕过 Pro；请用服务端测试账号验证 Pro。")
                .font(AppType.caption)
                .foregroundStyle(Theme.tertiaryText)
#endif

            Text(AppConfig.apiBaseURL.absoluteString)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.secondaryText)

            Button("测试连接") {
                testConnection()
            }
            .buttonStyle(SecondaryButtonStyle())
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
