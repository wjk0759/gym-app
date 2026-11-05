import SwiftUI
import UIKit

/// Detects a second tap on the already-selected tab.
///
/// SwiftUI's `TabView` has no reselect callback: tapping the current tab does
/// not change the selection binding, so `onChange` never fires. This observer
/// attaches a non-blocking tap recognizer to the underlying `UITabBar` and
/// reports only taps on the item that is already selected.
struct TabBarReselectObserver: UIViewControllerRepresentable {
    let onReselect: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReselect: onReselect)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        context.coordinator.attachWhenReady(to: controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onReselect = onReselect
        context.coordinator.attachWhenReady(to: uiViewController)
    }

    static func dismantleUIViewController(
        _ uiViewController: UIViewController,
        coordinator: Coordinator
    ) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onReselect: () -> Void

        private weak var tabBar: UITabBar?
        private weak var tabBarController: UITabBarController?
        private var tapRecognizer: UITapGestureRecognizer?

        init(onReselect: @escaping () -> Void) {
            self.onReselect = onReselect
        }

        func attachWhenReady(to controller: UIViewController, attempt: Int = 0) {
            DispatchQueue.main.async { [weak self, weak controller] in
                guard let self, let controller else { return }
                if self.attach(to: controller) { return }
                guard attempt < 5 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.attachWhenReady(to: controller, attempt: attempt + 1)
                }
            }
        }

        @discardableResult
        func attach(to controller: UIViewController) -> Bool {
            guard let tabBarController = controller.tabBarController else { return false }
            let tabBar = tabBarController.tabBar
            guard self.tabBar !== tabBar else { return true }

            detach()
            self.tabBarController = tabBarController
            self.tabBar = tabBar

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            tabBar.addGestureRecognizer(recognizer)
            tapRecognizer = recognizer
            return true
        }

        func detach() {
            if let tapRecognizer, let tabBar {
                tabBar.removeGestureRecognizer(tapRecognizer)
            }
            tapRecognizer = nil
            tabBar = nil
            tabBarController = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let tabBar,
                  let tabBarController,
                  let items = tabBar.items,
                  !items.isEmpty else { return }

            let location = recognizer.location(in: tabBar)
            guard tabBar.bounds.contains(location) else { return }

            let itemWidth = tabBar.bounds.width / CGFloat(items.count)
            guard itemWidth > 0 else { return }
            let index = min(items.count - 1, max(0, Int(location.x / itemWidth)))
            guard index == tabBarController.selectedIndex else { return }
            onReselect()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
