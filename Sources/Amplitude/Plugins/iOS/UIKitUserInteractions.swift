#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    struct EventData {
        enum Source {
            case actionMethod

            case gestureRecognizer
        }

        let viewController: String?

        let title: String?

        let accessibilityLabel: String?

        let accessibilityIdentifier: String?

        let targetViewClass: String

        let targetText: String?

        let hierarchy: String

        fileprivate func userInteractionEvent(for action: String, from source: Source? = nil, withName sourceName: String? = nil) -> UserInteractionEvent {
            return UserInteractionEvent(
                viewController: viewController,
                title: title,
                accessibilityLabel: accessibilityLabel,
                accessibilityIdentifier: accessibilityIdentifier,
                action: action,
                targetViewClass: targetViewClass,
                targetText: targetText,
                hierarchy: hierarchy,
                actionMethod: source == .actionMethod ? sourceName : nil,
                gestureRecognizer: source == .gestureRecognizer ? sourceName : nil
            )
        }
    }

    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let addNotificationObservers: Void = {
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(didEndEditing), name: UITextField.textDidEndEditingNotification, object: nil)
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

    @objc static func didEndEditing(_ notification: NSNotification) {
        guard let view = notification.object as? UIView else { return }
        let userInteractionEvent = view.eventData.userInteractionEvent(for: "didEndEditing")
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
              let control = sender as? UIControl,
              control.amp_shouldTrack(action, for: target),
              let actionEvent = control.event(for: action, to: target)?.description
        else { return sendActionResult }

        let userInteractionEvent = control.eventData.userInteractionEvent(for: actionEvent, from: .actionMethod, withName: NSStringFromSelector(action))

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

        let gestureAction: String? = switch self {
        case is UITapGestureRecognizer: "Tap"
        case is UISwipeGestureRecognizer: "Swipe"
        case is UIPanGestureRecognizer: "Pan"
        case is UILongPressGestureRecognizer: "Long Press"
#if !os(tvOS)
        case is UIPinchGestureRecognizer: "Pinch"
        case is UIRotationGestureRecognizer: "Rotation"
        case is UIScreenEdgePanGestureRecognizer: "Screen Edge Pan"
#endif
        default: nil
        }

        guard let gestureAction else { return }

        let userInteractionEvent = view.eventData.userInteractionEvent(for: gestureAction, from: .gestureRecognizer, withName: descriptiveTypeName)

        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }
}

extension UIView {
    private static let viewHierarchyDelimiter = " → "

    var eventData: UIKitUserInteractions.EventData {
        let viewController = owningViewController
        return UIKitUserInteractions.EventData(
            viewController: viewController?.descriptiveTypeName,
            title: viewController?.title,
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            targetViewClass: descriptiveTypeName,
            targetText: amp_title,
            hierarchy: sequence(first: self, next: \.superview)
                .map { $0.descriptiveTypeName }
                .joined(separator: UIView.viewHierarchyDelimiter))
    }
}

extension UIControl {
    func event(for action: Selector, to target: Any?) -> UIControl.Event? {
        var events: [UIControl.Event] = [
            .touchDown, .touchDownRepeat, .touchDragInside, .touchDragOutside,
            .touchDragEnter, .touchDragExit, .touchUpInside, .touchUpOutside,
            .touchCancel, .valueChanged, .editingDidBegin, .editingChanged,
            .editingDidEnd, .editingDidEndOnExit, .primaryActionTriggered
        ]
        if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, *) {
            events.append(.menuActionTriggered)
        }

        return events.first { event in
            self.actions(forTarget: target, forControlEvent: event)?.contains(action.description) ?? false
        }
    }
}

extension UIControl.Event {
    var description: String? {
        if UIControl.Event.allTouchEvents.contains(self) {
            return "Touch"
        } else if UIControl.Event.allEditingEvents.contains(self) {
            return "Edit"
        } else if self == .valueChanged {
            return "Value Change"
        } else if self == .primaryActionTriggered {
            return "Primary Action"
        } else if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, *), self == .menuActionTriggered {
            return "Menu Action"
        }
        return nil
    }
}

extension UIResponder {
    var owningViewController: UIViewController? {
        self as? UIViewController ?? next?.owningViewController
    }
}

extension NSObject {
    var descriptiveTypeName: String {
        String(describing: type(of: self))
    }
}

protocol ActionTrackable {
    var amp_title: String? { get }
    func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool
}

extension UIView: ActionTrackable {
    @objc var amp_title: String? { nil }
    @objc func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool { false }
}

extension UIControl {
    override func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool {
        actions(forTarget: target, forControlEvent: .touchUpInside)?.contains(action.description) ?? false
    }
}

extension UIButton {
    override var amp_title: String? { currentTitle }
}

extension UISegmentedControl {
    override var amp_title: String? { titleForSegment(at: selectedSegmentIndex) }
    override func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool {
        actions(forTarget: target, forControlEvent: .valueChanged)?.contains(action.description) ?? false
    }
}

extension UIPageControl {
    override func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool {
        actions(forTarget: target, forControlEvent: .valueChanged)?.contains(action.description) ?? false
    }
}

#if !os(tvOS)
extension UIDatePicker {
    override func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool {
        actions(forTarget: target, forControlEvent: .valueChanged)?.contains(action.description) ?? false
    }
}

extension UISwitch {
    override func amp_shouldTrack(_ action: Selector, for target: Any?) -> Bool {
        actions(forTarget: target, forControlEvent: .valueChanged)?.contains(action.description) ?? false
    }
}
#endif

#endif
