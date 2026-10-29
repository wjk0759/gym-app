import SwiftUI

enum LegalDocumentKind: String, Identifiable {
    case terms
    case privacy
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "用户协议"
        case .privacy: return "隐私政策"
        case .ai: return "生成式 AI 服务说明"
        }
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LegalDocumentKind

    private struct Section: Identifiable {
        let title: String
        let body: String
        var id: String { title }
    }

    private var intro: String {
        switch kind {
        case .terms:
            return "欢迎使用练途。本协议约定你与练途之间关于账号、训练计划、AI 教练、饮食记录和订阅服务的使用规则。请在使用前完整阅读。"
        case .privacy:
            return "练途重视你的个人信息与身体数据。本政策说明我们收集哪些信息、为什么收集、如何保护，以及你可以如何管理这些信息。"
        case .ai:
            return "本说明介绍练途中的生成式 AI 能力、内容边界和数据使用方式。"
        }
    }

    private var sections: [Section] {
        switch kind {
        case .terms:
            return [
                Section(title: "1. 服务内容与边界", body: "练途提供训练计划、动作说明、训练记录、饮食估算和 AI 对话等功能。这些内容用于一般健身与生活方式参考，不构成医疗诊断、治疗或营养处方。出现胸痛、眩晕、呼吸困难、急性损伤，或处于孕期、术后恢复期时，请先咨询医生。"),
                Section(title: "2. 账号注册与安全", body: "手机号验证通过，或使用微信/QQ 授权后，系统可能为你自动创建账号。请妥善保管验证码、密码与登录设备；发现异常登录时及时退出并修改密码。"),
                Section(title: "3. 订阅与自动续费", body: "练途 Pro 通过 Apple App Store 销售。价格、周期和试用条件以下单页面为准；订阅会自动续期，可在系统设置中取消。取消后，已付费周期内仍可使用 Pro 功能。"),
                Section(title: "4. AI 生成内容", body: "AI 计划与建议基于你填写的档案、器械、训练记录和对话内容生成，可能存在不准确或不适用的情况。请根据身体反应调整，不要将 AI 输出作为医疗依据。"),
                Section(title: "5. 使用规范", body: "不得利用本服务发布违法信息、侵犯他人权益、干扰系统运行或绕过安全限制。因违规导致的账号限制或终止，由用户承担相应责任。"),
                Section(title: "6. 知识产权", body: "App 界面、文本、图形和训练内容的知识产权归练途或授权方所有。未经许可不得复制、出售或用于商业培训。你上传的照片仅用于你主动选择的对应功能。"),
                Section(title: "7. 服务变更与终止", body: "我们可能因产品升级、合规要求或不可抗力调整服务，重大变更会通过 App 内提示。你可以随时停止使用。账号注销与数据删除需由运营方按法律法规和账号安全流程处理。"),
                Section(title: "8. 协议更新与联系", body: "协议更新后会在登录页或 App 内公示。继续使用视为接受更新内容；如不同意，可停止使用。对协议有疑问，可通过 App 内反馈渠道联系我们。")
            ]
        case .privacy:
            return [
                Section(title: "1. 我们收集的信息", body: "账号信息（手机号、微信/QQ 标识）；你主动填写的性别、年龄、身高、体重、围度、目标与训练偏好；训练记录、饮食记录、对话内容和器械库；你上传的器械照片、体型照片和食物照片；以及用于安全和故障排查的设备与日志信息。"),
                Section(title: "2. 敏感个人信息", body: "体型照片、食物照片、健康与身体数据可能属于敏感个人信息。我们仅在你主动使用对应功能并同意后处理；你可以拒绝或撤回同意，但相关功能将无法使用。"),
                Section(title: "3. 使用目的", body: "用于生成和调整训练/饮食计划、记录与复盘、提供 AI 教练回答、器械识别、保障账号与服务安全、处理订阅和客服问题。我们不会将健康数据用于广告定向。"),
                Section(title: "4. 存储与安全", body: "数据存储在中华人民共和国境内。我们采用访问控制、传输保护、权限隔离和日志审计等措施，仅在实现目的所需期限内保留；注销或删除后，按法律要求处理。"),
                Section(title: "5. 共享与委托处理", body: "我们不会出售个人信息。为提供短信验证、云托管、AI 推理、支付与登录服务，可能委托合作方处理必要信息，并通过协议约束其用途。除法律要求或取得单独同意外，不向第三方提供。"),
                Section(title: "6. 设备权限", body: "相机和相册用于器械、体型与食物照片；通知用于训练提醒；HealthKit 用于读写你授权的训练与体重数据。你可以在系统设置中随时关闭这些权限。"),
                Section(title: "7. 你的权利", body: "你可以访问、更正和导出个人数据，或撤回授权。账号注销与数据删除需由运营方按法律法规及账号安全流程处理。"),
                Section(title: "8. 未成年人保护", body: "未满 14 周岁的用户应在监护人同意和指导下使用；未满 18 周岁的用户应在监护人知情下使用订阅与训练功能。"),
                Section(title: "9. 更新与联系", body: "隐私政策更新会在 App 内公示。对个人信息处理有疑问，可通过 App 内反馈渠道联系我们。")
            ]
        case .ai:
            return [
                Section(title: "1. 服务说明", body: "生成式 AI 用于训练计划、动作替代、饮食建议和教练对话。当前版本可能使用规则引擎或模拟结果，正式模型接入后会更新本说明。"),
                Section(title: "2. 不提供医疗诊断", body: "AI 输出不能替代医生、康复师或营养师的专业意见。出现疼痛、眩晕、胸闷、呼吸困难，或处于孕期、术后恢复期时，请先就医或咨询专业人士。"),
                Section(title: "3. 内容局限", body: "AI 可能产生不准确、不完整或不适用的建议。请结合器械条件、动作能力和身体反应判断，必要时降低负荷或停止训练。"),
                Section(title: "4. 数据与模型", body: "AI 回答会使用你主动提供的档案、训练、饮食和对话信息。我们不会将你的对话用于公开展示；如使用第三方模型服务，将按最小必要原则传输并约束用途。"),
                Section(title: "5. 备案与公示", body: "正式上线前将完成适用的生成式人工智能服务与算法备案，并在 App 内公示模型提供方、备案信息和处理规则。"),
                Section(title: "6. 安全反馈", body: "如果你发现错误、歧视性内容或其他安全问题，请通过 App 内反馈渠道告诉我们，我们会核查并改进。")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("练途 · 协议与隐私")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accentText)
                        Spacer()
                        Text("更新于 2026-10-25")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Text(kind.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("本页为应用内公示文本。正式上线版本将在 App Store 页面与 App 内同步更新，并由法务复核。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .tint(Theme.accentText)
    }
}
