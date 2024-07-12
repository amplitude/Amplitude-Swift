#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let initializeSwizzle: () = {
        swizzleSendAction()
    }()

    private static let initializeNotificationListeners: () = {
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(UIKitUserInteractions.amp_textFieldDidBeginEditing), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(UIKitUserInteractions.amp_textFieldDidEndEditing), name: UITextField.textDidEndEditingNotification, object: nil)
    }()

    static func register(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.add(amplitude)
        }
        initializeSwizzle
        initializeNotificationListeners
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

    @objc static func amp_textFieldDidBeginEditing(_ notification: NSNotification) {
        guard let textField = notification.object as? UITextField else { return }
        let userInteractionEvent = textField.eventFromData(with: "didBeginEditing")
        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }

    @objc static func amp_textFieldDidEndEditing(_ notification: NSNotification) {
        guard let textField = notification.object as? UITextField else { return }
        let userInteractionEvent = textField.eventFromData(with: "didEndEditing")
        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }
}

extension UIApplication {
    @objc func amp_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let sendActionResult = amp_sendAction(action, to: target, from: sender, for: event)

        guard
            sendActionResult,
            let view = sender as? UIView,
            view.shouldTrack(action, for: event)
        else { return sendActionResult }

        let userInteractionEvent = view.eventFromData(with: NSStringFromSelector(action).components(separatedBy: ":").first ?? "")

        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
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
        let action: String
        let targetViewClass: String
        let targetText: String?
        let hierarchy: String
    }

    func eventFromData(with action: String) -> UserInteractionEvent {
        let viewData = extractData(with: action)
        return UserInteractionEvent(
            viewController: viewData.viewController,
            title: viewData.title,
            accessibilityLabel: viewData.accessibilityLabel,
            action: viewData.action,
            targetViewClass: viewData.targetViewClass,
            targetText: viewData.targetText,
            hierarchy: viewData.hierarchy)
    }

    func extractData(with action: String) -> ViewData {
        let viewController = owningViewController
        return ViewData(
            viewController: viewController?.descriptiveTypeName,
            title: viewController?.title,
            accessibilityLabel: accessibilityLabel,
            action: action,
            targetViewClass: descriptiveTypeName,
            targetText: title,
            hierarchy: sequence(first: self, next: { $0.superview })
                .map { $0.descriptiveTypeName }
                .joined(separator: UIView.viewHierarchyDelimiter))
    }
}

extension UIResponder {
    var descriptiveTypeName: String {
        String(describing: type(of: self))
    }

    var owningViewController: UIViewController? {
        return self as? UIViewController ?? next?.owningViewController
    }
}

extension UIView {
    var title: String? {
        switch self {
        case let button as UIButton:
            return button.currentTitle
        case let segmentedControl as UISegmentedControl:
            return segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
        default:
            return nil
        }
    }

    func shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool {
        switch self {
        case is UITextField:
            return false
        #if !os(tvOS)
        case is UISlider:
            return event?.allTouches?.contains { $0.phase == .ended && $0.view == self } ?? false
        #endif
        default:
            return true
        }
    }
}

#endif
