import Foundation
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitScreenViews {
    internal static let lock = NSLock()
    internal static var amplitudes: [Weak<Amplitude>] = []
    private static var viewDidAppearSwizzled = false

    static func register(_ amplitude: Amplitude) {
        lock.lock()
        defer { lock.unlock() }

        amplitudes.append(Weak(amplitude))
        if viewDidAppearSwizzled {
            return
        }

        viewDidAppearSwizzled = true
        swizzleViewDidAppear()
    }

    private static func swizzleViewDidAppear() {
        let controllerClass = UIViewController.self
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.amp_viewDidAppear(_:))

        guard let originalViewDidAppear = class_getInstanceMethod(controllerClass, originalSelector) else { return }
        guard let swizzledViewDidAppear = class_getInstanceMethod(controllerClass, swizzledSelector) else { return }

        let methodAdded = class_addMethod(
            controllerClass,
            originalSelector,
            method_getImplementation(swizzledViewDidAppear),
            method_getTypeEncoding(swizzledViewDidAppear)
        )

        if methodAdded {
            class_replaceMethod(
                controllerClass,
                swizzledSelector,
                method_getImplementation(originalViewDidAppear),
                method_getTypeEncoding(originalViewDidAppear)
            )
        } else {
            method_exchangeImplementations(originalViewDidAppear, swizzledViewDidAppear)
        }
    }

    static func screenName(for viewController: UIViewController) -> String {
        if let title = viewController.title, !title.isEmpty {
            return title
        }
        let className = String(describing: type(of: viewController))
            .replacingOccurrences(of: "ViewController", with: "")
        if !className.isEmpty {
            return className
        }
        return "Unknown"
    }
}

extension UIViewController {

    @objc func amp_viewDidAppear(_ animated: Bool) {
        amp_viewDidAppear(animated)

        // Only record screen events for view controllers owned by the app
        let viewControllerBundlePath = Bundle(for: classForCoder).bundleURL.resolvingSymlinksInPath().path
        let mainBundlePath = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        guard viewControllerBundlePath.hasPrefix(mainBundlePath) else {
            return
        }

        guard let rootViewController = viewIfLoaded?.window?.rootViewController else {
            return
        }

        guard let top = Self.amp_topViewController(rootViewController) else {
            return
        }

        let screenName = UIKitScreenViews.screenName(for: top)

        for amplitude in UIKitScreenViews.amplitudes {
            amplitude.value?.track(event: ScreenViewedEvent(screenName: screenName))
        }
    }

    static func amp_topViewController(_ rootViewController: UIViewController) -> UIViewController? {
        if let nextController = amp_nextRootViewController(rootViewController) {
            return amp_topViewController(nextController)
        }
        return rootViewController
    }

    static func amp_nextRootViewController(_ rootViewController: UIViewController) -> UIViewController? {
        if let presentedViewController = rootViewController.presentedViewController {
            return presentedViewController
        }

        if let navigationController = rootViewController as? UINavigationController {
            if let visibleViewController = navigationController.visibleViewController {
                return visibleViewController
            }
        }

        if let tabBarController = rootViewController as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return selectedViewController
            }
        }

        if rootViewController.children.count > 0 {
            if let firstChildViewController = rootViewController.children.first {
                return firstChildViewController
            }
        }

        return nil
    }
}

#endif
