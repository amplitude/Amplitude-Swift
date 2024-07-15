#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let addNotificationObservers: () = {
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didBeginEditing), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didEndEditing), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didBeginEditing), name: UITextView.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didEndEditing), name: UITextView.textDidEndEditingNotification, object: nil)
    }()

    private static let swizzleSendAction: () = {
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
    }()

    static func register(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.add(amplitude)
        }
        swizzleSendAction
        addNotificationObservers
    }

    @objc static func didBeginEditing(_ notification: NSNotification) {
        guard let view = notification.object as? UIView else { return }
        let userInteractionEvent = view.eventFromData(with: "didBeginEditing")
        amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }

    @objc static func didEndEditing(_ notification: NSNotification) {
        guard let view = notification.object as? UIView else { return }
        let userInteractionEvent = view.eventFromData(with: "didEndEditing")
        amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }
}

extension UIApplication {
    @objc func amp_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let sendActionResult = amp_sendAction(action, to: target, from: sender, for: event)

        guard sendActionResult,
            let view = sender as? UIView,
            view.amp_shouldTrack(action, for: event),
            let actionName = NSStringFromSelector(action)
                .components(separatedBy: ":")
                .first
        else { return sendActionResult }

        let userInteractionEvent = view.eventFromData(with: actionName)

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
            targetText: amp_title,
            hierarchy: sequence(first: self, next: \.superview)
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

protocol ActionTrackable {
    var amp_title: String? { get }
    func amp_shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool
}

extension UIView: ActionTrackable {
    @objc var amp_title: String? { nil }
    @objc func amp_shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool { true }
}

extension UIButton {
    override var amp_title: String? { currentTitle }
}

extension UISegmentedControl {
    override var amp_title: String? { titleForSegment(at: selectedSegmentIndex) }
}

extension UITextField {
    override func amp_shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool { false }
}

extension UITextView {
    override func amp_shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool { false }
}

#if !os(tvOS)
extension UISlider {
    override func amp_shouldTrack(_ action: Selector, for event: UIEvent?) -> Bool {
        event?.allTouches?.contains { $0.phase == .ended && $0.view === self } ?? false
    }
}

@available(iOS 14.0, *)
extension UIColorWell {
    override var amp_title: String? { title }
}
#endif

#endif
