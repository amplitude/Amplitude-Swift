#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let initializeSwizzle: () = {
        swizzleSendAction()
    }()
    
    private static let initializeNotificationListeners: () = {
        NotificationCenter.default.addObserver(UITextField.self, selector: #selector(UITextField.amp_textFieldBeganEditing), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UITextField.self, selector: #selector(UITextField.amp_textFieldEndedEditing), name: UITextField.textDidEndEditingNotification, object: nil)
    }()

    static func register(_ amplitude: Amplitude) {
        lock.lock()
        amplitudeInstances.add(amplitude)
        lock.unlock()
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
}

extension UIApplication {
    @objc func amp_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let sendActionResult = amp_sendAction(action, to: target, from: sender, for: event)

        guard
            sendActionResult,
            let view = sender as? UIView
        else { return sendActionResult }

        if let textField = view as? UITextField, !textField.shouldTrack(action, for: event) {
            return sendActionResult
        } else {
            #if !os(tvOS)
            if let slider = view as? UISlider, !slider.shouldTrack(action, for: event) {
                return sendActionResult
            }
            #endif
        }

        let userInteractionEvent = view.eventFromData(with: action)

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
        let actionMethod: String
        let targetViewClass: String
        let targetText: String?
        let hierarchy: String
    }
    
    func eventFromData(with action: Selector) -> UserInteractionEvent {
        let viewData = extractData(with: action)
        return UserInteractionEvent(
            viewController: viewData.viewController,
            title: viewData.title,
            accessibilityLabel: viewData.accessibilityLabel,
            actionMethod: viewData.actionMethod,
            targetViewClass: viewData.targetViewClass,
            targetText: viewData.targetText,
            hierarchy: viewData.hierarchy)
    }

    func extractData(with action: Selector) -> ViewData {
        var targetText: String?

        if let button = self as? UIButton {
            targetText = button.currentTitle
        } else if let textField = self as? UITextField {
            targetText = String(textField.tag)
        } else if let segmentedControl = self as? UISegmentedControl {
            targetText = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex)
        } else {
            #if !os(tvOS)
            if #available(iOS 14.0, macCatalyst 14.0, *) {
                if let colorWell = self as? UIColorWell {
                    targetText = colorWell.title
                } else if let `switch` = self as? UISwitch {
                    targetText = `switch`.title
                }
            }
            #endif
        }

        let viewController = owningViewController
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

    var owningViewController: UIViewController? {
        return self as? UIViewController ?? next?.owningViewController
    }
}

protocol Trackable {
    func shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool
}

extension UITextField: Trackable {
    func shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool {
        false
    }
    
    @objc static func amp_textFieldBeganEditing(_ notification: NSNotification) {
        guard let textField = notification.object as? UITextField else { return }
        let userInteractionEvent = textField.eventFromData(with: #selector(UITextField.amp_textFieldBeganEditing))
        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }
    
    @objc static func amp_textFieldEndedEditing(_ notification: NSNotification) {
        guard let textField = notification.object as? UITextField else { return }
        let userInteractionEvent = textField.eventFromData(with: #selector(UITextField.amp_textFieldEndedEditing))
        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }
}

#if !os(tvOS)
extension UISlider: Trackable {
    func shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool {
        event?.allTouches?.contains { $0.phase == .ended && $0.view == self } ?? false
    }
}
#endif

#endif
