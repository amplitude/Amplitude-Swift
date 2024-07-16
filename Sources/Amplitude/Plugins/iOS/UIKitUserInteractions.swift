#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let addNotificationObservers: Void = {
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didBeginEditing), name: UITextField.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didEndEditing), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didBeginEditing), name: UITextView.textDidBeginEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didEndEditing), name: UITextView.textDidEndEditingNotification, object: nil)
    }()

    private static let setupMethodSwizzling: Void = {
        swizzleMethod(UIApplication.self, from: #selector(UIApplication.sendAction), to: #selector(UIApplication.amp_sendAction))
        swizzleMethod(UIGestureRecognizer.self, from: #selector(setter: UIGestureRecognizer.state), to: #selector(UIGestureRecognizer.amp_setState))
    }()

    static func register(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.add(amplitude)
        }
        setupMethodSwizzling
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

    private static func swizzleMethod(_ cls: AnyClass?, from original: Selector, to swizzled: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(cls, original),
            let swizzledMethod = class_getInstanceMethod(cls, swizzled)
        else { return }

        let originalImp = method_getImplementation(originalMethod)
        let swizzledImp = method_getImplementation(swizzledMethod)

        class_replaceMethod(cls,
            swizzled,
            originalImp,
            method_getTypeEncoding(originalMethod))
        class_replaceMethod(cls,
            original,
            swizzledImp,
            method_getTypeEncoding(swizzledMethod))
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

extension UIGestureRecognizer {
    @objc func amp_setState(_ state: UIGestureRecognizer.State) {
        amp_setState(state)

        guard state == .ended, let view else { return }

        let gestureType = switch self {
        case is UITapGestureRecognizer: "Tap"
        case is UIPinchGestureRecognizer: "Pinch"
        case is UIRotationGestureRecognizer: "Rotation"
        case is UISwipeGestureRecognizer: "Swipe"
        case is UIPanGestureRecognizer: "Pan"
        case is UIScreenEdgePanGestureRecognizer: "Screen Edge Pan"
        case is UILongPressGestureRecognizer: "Long Press"
        default: "Custom Gesture"
        }

        let userInteractionEvent = eventFromData(with: gestureType, from: view)

        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }

    func eventFromData(with action: String, from view: UIView) -> UserInteractionEvent {
        let viewData = view.extractData(with: action)
        return UserInteractionEvent(
            viewController: viewData.viewController,
            title: viewData.title,
            accessibilityLabel: viewData.accessibilityLabel,
            action: viewData.action,
            targetViewClass: viewData.targetViewClass,
            targetText: viewData.targetText,
            hierarchy: viewData.hierarchy,
            gestureRecognizer: descriptiveTypeName)
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
    var owningViewController: UIViewController? {
        return self as? UIViewController ?? next?.owningViewController
    }
}

extension NSObject {
    var descriptiveTypeName: String {
        String(describing: type(of: self))
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
