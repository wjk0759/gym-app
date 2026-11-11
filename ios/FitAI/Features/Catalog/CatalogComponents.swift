import SwiftUI

/// 动作库 / 器械库共用的目录搜索框。
struct CatalogSearchField<Trailing: View>: View {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int?
    let trailing: Trailing

    init(
        text: Binding<String>,
        placeholder: String,
        maxLength: Int? = 60,
        @ViewBuilder trailing: () -> Trailing
    ) {
        _text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.tertiaryText.opacity(0.82))

            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
                .onChange(of: text) { _, value in
                    if let maxLength, value.count > maxLength {
                        text = String(value.prefix(maxLength))
                    }
                }

            if !text.isEmpty {
                Button {
                    Haptics.tap()
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.9))
                .accessibilityLabel("清空搜索")
            }

            trailing
        }
        .padding(.leading, 13)
        .padding(.trailing, 7)
        .padding(.vertical, 6)
        .frame(minHeight: 48)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

extension CatalogSearchField where Trailing == EmptyView {
    init(text: Binding<String>, placeholder: String, maxLength: Int? = 60) {
        self.init(text: text, placeholder: placeholder, maxLength: maxLength) {
            EmptyView()
        }
    }
}

/// 目录左侧栏外壳：宽度、滚动、纸张背景和描边保持一致。
struct CatalogSidebarContainer<Content: View>: View {
    var width: CGFloat = 80
    let content: Content

    init(width: CGFloat = 80, @ViewBuilder content: () -> Content) {
        self.width = width
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 1) {
                content
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        }
        .frame(width: width)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }
}

/// 目录一级按钮；count 为 nil 时不显示数量。
struct CatalogSidebarButton: View {
    let title: String
    var count: Int? = nil
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? Theme.onPrimary : Theme.secondaryText.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let count {
                    Text("\(count)")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(
                            active ? Theme.onPrimary.opacity(0.72) : Theme.tertiaryText
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, count == nil ? 6.5 : 5.5)
            .background(
                active ? Theme.primary : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(active ? Theme.ink.opacity(0.12) : Color.clear, lineWidth: 1)
            }
            .animation(Motion.quick, value: active)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityLabel("\(title)分类")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// 目录二级按钮：缩进、浅 cobalt 选中态。
struct CatalogSidebarSubButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(.system(size: 10, weight: active ? .bold : .medium))
                .foregroundStyle(active ? Theme.cobalt : Theme.secondaryText.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5.5)
                .padding(.leading, 5)
                .background(
                    active ? Theme.cobalt.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(active ? Theme.cobalt.opacity(0.16) : Color.clear, lineWidth: 1)
                }
                .animation(Motion.quick, value: active)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
        .accessibilityLabel("\(title)肌群")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// 二级分类组：左侧细线 + 缩进。
struct CatalogSidebarChildren<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 1) {
            content
        }
        .padding(.leading, 6)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Theme.cobalt.opacity(0.22))
                .frame(width: 1.5)
                .padding(.vertical, 2)
        }
    }
}

/// 目录两栏布局：左栏 + 右侧内容。没有侧栏时只渲染内容。
struct CatalogTwoColumnLayout<Sidebar: View, Content: View>: View {
    var showSidebar: Bool = true
    let sidebar: Sidebar
    let content: Content

    init(
        showSidebar: Bool = true,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content
    ) {
        self.showSidebar = showSidebar
        self.sidebar = sidebar()
        self.content = content()
    }

    var body: some View {
        if showSidebar {
            HStack(alignment: .top, spacing: 9) {
                sidebar
                content
            }
        } else {
            content
        }
    }
}

/// 目录空状态。
struct CatalogEmptyCard: View {
    var icon: String = "magnifyingglass"
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
            Text(title)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }
}
