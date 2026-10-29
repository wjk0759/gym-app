import SwiftUI
import UIKit

extension View {
    /// VoiceOver 不会自动播报 Section footer 中新出现的错误；
    /// 认证流程统一通过系统 announcement 播报一次。
    func announcesAuthError(_ message: String?) -> some View {
        onChange(of: message) { _, newValue in
            guard let newValue, !newValue.isEmpty else { return }
            UIAccessibility.post(notification: .announcement, argument: newValue)
        }
    }
}
