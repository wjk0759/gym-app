import SwiftUI

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value = AppConfig.apiBaseURLString

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("真机调试时改成电脑局域网地址。例如：")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("http://192.168.1.4:8000/api/v1")
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.accentText)
                } footer: {
                    Text("仅 Debug 构建显示。Release 使用固定生产域名。")
                }

                Section("API 地址") {
                    TextField("http://192.168.1.4:8000/api/v1", text: $value)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section {
                    Button {
                        AppConfig.setAPIBaseURL(value)
                        dismiss()
                    } label: {
                        Text("保存")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Theme.accentFill)

                    Button {
                        value = "http://127.0.0.1:8000/api/v1"
                        AppConfig.setAPIBaseURL(nil)
                    } label: {
                        Text("恢复默认")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(Theme.accentText)
                }
            }
            .navigationTitle("开发服务器")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .tint(Theme.accentText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        KeyboardDismiss.dismiss()
                    }
                }
            }
        }
        .tint(Theme.accentText)
    }
}
