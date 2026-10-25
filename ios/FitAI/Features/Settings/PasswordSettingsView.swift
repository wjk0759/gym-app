import SwiftUI

struct PasswordSettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage = ""
    @State private var showSuccess = false

    private var isValid: Bool {
        password.count >= 8
            && password.contains(where: { $0.isLetter })
            && password.contains(where: { $0.isNumber })
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("设置密码后，可以用手机号或用户名 + 密码登录。修改后，其他已登录设备需要重新验证。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .card()

                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("新密码")
                        SecureField("至少 8 位，含字母和数字", text: $password)
                            .textContentType(.newPassword)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 1)
                            )
                            .onChange(of: password) { _, _ in errorMessage = "" }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        fieldLabel("确认新密码")
                        SecureField("再次输入新密码", text: $confirmation)
                            .textContentType(.newPassword)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 1)
                            )
                            .onChange(of: confirmation) { _, _ in errorMessage = "" }
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        save()
                    } label: {
                        if auth.isWorking {
                            ProgressView().tint(.black)
                        } else {
                            Text("保存密码")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(auth.isWorking)
                }
                .padding(20)
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("登录密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("密码已保存", isPresented: $showSuccess) {
                Button("完成") { dismiss() }
            } message: {
                Text("下次登录请使用新密码。")
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.leading, 2)
    }

    private func save() {
        guard isValid else {
            errorMessage = "密码至少 8 位，并同时包含字母和数字"
            return
        }
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        Task { @MainActor in
            do {
                try await auth.setPassword(password)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
