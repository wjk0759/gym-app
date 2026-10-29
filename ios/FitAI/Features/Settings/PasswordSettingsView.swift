import SwiftUI

struct PasswordSettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case password
        case confirmation
    }

    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @FocusState private var focusedField: Field?

    private var isValid: Bool {
        password.count >= 8
            && password.contains(where: { $0.isLetter })
            && password.contains(where: { $0.isNumber })
    }

    var body: some View {
        Form {
            Section {
                Group {
                    if showPassword {
                        TextField("新密码", text: $password)
                    } else {
                        SecureField("新密码", text: $password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmation
                }
                .accessibilityLabel("新密码")
                .onChange(of: password) { _, _ in
                    errorMessage = nil
                }

                Group {
                    if showPassword {
                        TextField("确认新密码", text: $confirmation)
                    } else {
                        SecureField("确认新密码", text: $confirmation)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit {
                    save()
                }
                .accessibilityLabel("确认新密码")
                .onChange(of: confirmation) { _, _ in
                    errorMessage = nil
                }

                Toggle("显示密码", isOn: $showPassword)
                    .tint(Theme.accentText)
            } header: {
                Text("新密码")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置后可用手机号或用户名 + 密码登录；修改后其他已登录设备需要重新验证。")
                    Text("至少 8 位，需同时包含字母和数字。")
                }
            }
            .disabled(isSubmitting)

            Section {
                Button {
                    save()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.onAccentFill)
                        }
                        Text(isSubmitting ? "正在保存…" : "保存密码")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onAccentFill)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accentFill)
                .disabled(isSubmitting)
                .accessibilityLabel(isSubmitting ? "正在保存密码" : "保存密码")
            } footer: {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("登录密码")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accentText)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .alert("密码已保存", isPresented: $showSuccess) {
            Button("完成") {
                dismiss()
            }
        } message: {
            Text("下次登录请使用新密码。")
        }
        .sensoryFeedback(.error, trigger: errorMessage) { _, newValue in
            newValue != nil
        }
        .sensoryFeedback(.success, trigger: showSuccess) { _, newValue in
            newValue
        }
        .announcesAuthError(errorMessage)
    }

    private func save() {
        guard !isSubmitting else { return }
        guard isValid else {
            errorMessage = "密码至少 8 位，并同时包含字母和数字"
            focusedField = .password
            return
        }
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致"
            focusedField = .confirmation
            return
        }

        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await auth.setPassword(password)
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
