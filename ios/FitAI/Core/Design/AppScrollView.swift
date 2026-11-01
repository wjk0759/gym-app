import SwiftUI

/// 全局内容滚动容器：统一隐藏滚动条、支持拖动收起键盘。
struct AppScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: AppLayout.readableMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        // Forms often fit on one screen. Allowing bounce gives the
        // interactive keyboard dismissal a drag to observe on short pages.
        .scrollBounceBehavior(.always)
    }
}
