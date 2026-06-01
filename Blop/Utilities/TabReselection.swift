import UIKit
import SwiftUI

extension Notification.Name {
    static let goToToday = Notification.Name("blop.goToToday")
    static let goToCurrentMonth = Notification.Name("blop.goToCurrentMonth")
    static let goToFutureLog = Notification.Name("blop.goToFutureLog")
    static let signifierToast = Notification.Name("blop.signifierToast")
}

/// Invisible UIView that walks the responder chain to find the UITabBarController
/// and intercepts re-taps on already-selected tabs, posting a notification.
struct TabReselectionCoordinator: UIViewRepresentable {
    func makeUIView(context: Context) -> TabProbeView { TabProbeView() }
    func updateUIView(_ uiView: TabProbeView, context: Context) {}
}

final class TabProbeView: UIView {
    private var tabDelegate: TabReselectDelegate?

    init() {
        super.init(frame: .zero)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, tabDelegate == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let tbc = next as? UITabBarController {
                    let d = TabReselectDelegate()
                    d.previous = tbc.delegate
                    tbc.delegate = d
                    self.tabDelegate = d
                    return
                }
                responder = next
            }
        }
    }
}

private final class TabReselectDelegate: NSObject, UITabBarControllerDelegate {
    weak var previous: UITabBarControllerDelegate?

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if tabBarController.selectedViewController === viewController {
            switch tabBarController.selectedIndex {
            case 0: NotificationCenter.default.post(name: .goToToday, object: nil)
            case 1: NotificationCenter.default.post(name: .goToCurrentMonth, object: nil)
            case 2: NotificationCenter.default.post(name: .goToFutureLog, object: nil)
            default: break
            }
        }
        return previous?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
    }
}
