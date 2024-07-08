#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let queue = DispatchQueue(label: "com.amplitude.autocapture", target: .global(qos: .utility))

    private static let initializeSwizzle: () = {
        swizzleSendAction()
    }()

    static func register(_ amplitude: Amplitude) {
        queue.sync {
            amplitudeInstances.add(amplitude)
        }
        initializeSwizzle
    }

    private static func swizzleSendAction() {
        let applicationClass = UIApplication.self

        let originalSelector = #selector(UIApplication.sendAction)
        let swizzledSelector = #selector(UIApplication.amp_sendAction)

        guard
            let originalMethod = class_getInstanceMethod(applicationClass, originalSelector),
            let swizzledMethod = class_getInstanceMethod(applicationClass, swizzledSelector)
        else { return }

        let originalImp = method_getImplementation(originalMethod)
        let swizzledImp = method_getImplementation(swizzledMethod)

        class_replaceMethod(applicationClass,
            swizzledSelector,
            originalImp,
            method_getTypeEncoding(originalMethod))
        class_replaceMethod(applicationClass,
            originalSelector,
            swizzledImp,
            method_getTypeEncoding(swizzledMethod))
    }
}

extension UIApplication {
    private var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    @objc dynamic func amp_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let sendActionResult = amp_sendAction(action, to: target, from: sender, for: event)

        guard
            let keyWindow = keyWindow,
            let view = sender as? UIView,
            !(view is UITextField),
            !(view is UISlider)
        else { return sendActionResult }

        let viewData = view.extractData(with: action, in: keyWindow)

        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: UserInteractionEvent(
                viewController: viewData.viewController,
                title: viewData.title,
                accessibilityLabel: viewData.accessibilityLabel,
                actionMethod: viewData.actionMethod,
                targetViewClass: viewData.targetViewClass,
                targetText: viewData.targetText,
                hierarchy: viewData.hierarchy))
        }

        return sendActionResult
    }
}

extension UIView {
    private static let viewHierarchyDelimiter = " -> "

    struct ViewData {
        let viewController: String?
        let title: String?
        let accessibilityLabel: String?
        let actionMethod: String
        let targetViewClass: String
        let targetText: String?
        let hierarchy: String
    }

    func extractData(with action: Selector, in window: UIWindow) -> ViewData {
        var targetText: String?

        if let button = self as? UIButton {
            targetText = button.titleLabel?.text
        }

        let viewController = window.rootViewController
        let viewControllerClassName = viewController?.descriptiveTypeName
        let viewControllerTitle = viewController?.title
        let targetAccessibilityLabel = self.accessibilityLabel
        let actionName = NSStringFromSelector(action)
        let targetViewClassName = self.descriptiveTypeName
        let viewHierarchy = sequence(first: self, next: { $0.superview })
            .map { $0.descriptiveTypeName }
            .joined(separator: UIView.viewHierarchyDelimiter)

        return ViewData(
            viewController: viewControllerClassName,
            title: viewControllerTitle,
            accessibilityLabel: targetAccessibilityLabel,
            actionMethod: actionName,
            targetViewClass: targetViewClassName,
            targetText: targetText,
            hierarchy: viewHierarchy)
    }
}

extension UIResponder {
    var descriptiveTypeName: String {
        String(describing: type(of: self))
    }
}

#endif
