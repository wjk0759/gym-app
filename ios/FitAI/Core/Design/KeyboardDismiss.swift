import SwiftUI
import UIKit

/// 在 window 级别安装一个不拦截业务点击的轻触手势。
/// 点到输入框以外的地方时收起键盘，点到输入框本身时保持编辑状态。
final class KeyboardDismissController: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissController()

    private weak var installedWindow: UIWindow?
    private var tapRecognizer: UITapGestureRecognizer?

    private override init() {
        super.init()
    }

    func attach(to window: UIWindow?) {
        guard let window else { return }
        if installedWindow === window, tapRecognizer != nil {
            return
        }

        if let oldWindow = installedWindow, let oldRecognizer = tapRecognizer {
            oldWindow.removeGestureRecognizer(oldRecognizer)
        }

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)

        installedWindow = window
        tapRecognizer = recognizer
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        var candidate = touch.view
        while let view = candidate {
            if view is UITextField || view is UITextView || view is UISearchBar {
                return false
            }
            candidate = view.superview
        }
        return true
    }
}

private final class KeyboardDismissWindowProbe: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?(window)
    }
}

/// 放在 RootView 的透明探针；拿到 window 后只安装一次手势。
struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissWindowProbe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowChange = { window in
            KeyboardDismissController.shared.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let window = uiView.window {
            KeyboardDismissController.shared.attach(to: window)
        }
    }
}

private struct KeyboardVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var keyboardVisible: Bool {
        get { self[KeyboardVisibleKey.self] }
        set { self[KeyboardVisibleKey.self] = newValue }
    }
}
