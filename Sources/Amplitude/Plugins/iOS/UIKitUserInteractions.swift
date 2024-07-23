#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
import UIKit

class UIKitUserInteractions {
    struct EventData {
        let viewController: String?

        let title: String?

        let accessibilityLabel: String?

        let accessibilityIdentifier: String?

        let targetViewClass: String

        let targetText: String?

        let hierarchy: String

        fileprivate func userInteractionEvent(for action: String, fromActionMethod actionMethod: String? = nil, fromGestureRecognizer gestureRecognizer: String? = nil) -> UserInteractionEvent {
            return UserInteractionEvent(
                viewController: viewController,
                title: title,
                accessibilityLabel: accessibilityLabel,
                accessibilityIdentifier: accessibilityIdentifier,
                action: action,
                targetViewClass: targetViewClass,
                targetText: targetText,
                hierarchy: hierarchy,
                actionMethod: actionMethod,
                gestureRecognizer: gestureRecognizer
            )
        }
    }

    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()

    private static let lock = NSLock()

    private static let setupMethodSwizzling: Void = {
        swizzleMethod(UIApplication.self, from: #selector(UIApplication.sendAction), to: #selector(UIApplication.amp_sendAction))
        swizzleMethod(UIGestureRecognizer.self, from: #selector(setter: UIGestureRecognizer.state), to: #selector(UIGestureRecognizer.amp_setState))
    }()

    static func register(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.add(amplitude)
        }
        setupMethodSwizzling
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

        guard sendActionResult, let control = sender as? UIControl else { return sendActionResult }

        coalesceAction(action, to: target, from: control)

        return sendActionResult
    }

    // MARK: Coalesce logically continuous events into a single event

    private class CoalescedEvent {
        let controlIdentifier: ObjectIdentifier

        let eventData: UIKitUserInteractions.EventData

        var terminated = false

        private(set) var actionMethod: (name: Selector, event: UIControl.Event)

        init(_ eventData: UIKitUserInteractions.EventData, for action: Selector, with contorlEvent: UIControl.Event, from control: UIControl) {
            self.controlIdentifier = ObjectIdentifier(control)
            self.eventData = eventData
            self.actionMethod = (action, contorlEvent)
        }

        func changeAction(_ action: Selector, with contorlEvent: UIControl.Event) {
            if !terminated {
                actionMethod = (action, contorlEvent)
            }
        }
    }

    private static var coalesceTask: DispatchWorkItem?

    private static var coalescedEvents = [CoalescedEvent]()

    private func coalesceAction(_ action: Selector, to target: Any?, from control: UIControl) {
        let controlIdentifier = ObjectIdentifier(control)
        let controlEvent = control.event(for: action, to: target)

        guard let controlEvent else { return }

        if let recentEvent = UIApplication.coalescedEvents.last {
            if recentEvent.controlIdentifier == controlIdentifier {
                recentEvent.changeAction(action, with: controlEvent)
                recentEvent.terminated = control.isActionTerminal(action, to: target)
            } else {
                recentEvent.terminated = true
                let newEvent = CoalescedEvent(control.eventData, for: action, with: controlEvent, from: control)
                UIApplication.coalescedEvents.append(newEvent)
            }
        } else {
            let newEvent = CoalescedEvent(control.eventData, for: action, with: controlEvent, from: control)
            UIApplication.coalescedEvents.append(newEvent)
        }

        UIApplication.coalesceTask?.cancel()

        let task = DispatchWorkItem {
            while UIApplication.coalescedEvents.first?.terminated ?? false {
                let coalescedEvent = UIApplication.coalescedEvents.removeFirst()

                let action = coalescedEvent.actionMethod.event.description

                let actionMethod = coalescedEvent.actionMethod.name.description

                let userInteractionEvent = coalescedEvent.eventData.userInteractionEvent(for: action, fromActionMethod: actionMethod)

                UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
                    $0.track(event: userInteractionEvent)
                }
            }
        }

        UIApplication.coalesceTask = task

        DispatchQueue.main.async(execute: task)
    }
}

extension UIGestureRecognizer {
    @objc func amp_setState(_ state: UIGestureRecognizer.State) {
        amp_setState(state)

        guard state == .ended, let view else { return }

        let gestureType = switch self {
        case is UITapGestureRecognizer: "Tap"
        case is UISwipeGestureRecognizer: "Swipe"
        case is UIPanGestureRecognizer: "Pan"
        case is UILongPressGestureRecognizer: "Long Press"
#if !os(tvOS)
        case is UIPinchGestureRecognizer: "Pinch"
        case is UIRotationGestureRecognizer: "Rotation"
        case is UIScreenEdgePanGestureRecognizer: "Screen Edge Pan"
#endif
        default: "Custom Gesture"
        }

        let userInteractionEvent = eventFromData(with: gestureType, from: view)

        UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
            $0.track(event: userInteractionEvent)
        }
    }

    func eventFromData(with action: String, from view: UIView) -> UserInteractionEvent {
        return view.eventData.userInteractionEvent(for: action, fromGestureRecognizer: self.descriptiveTypeName)
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
        if #available(iOS 14.0, *) {
            events.append(.menuActionTriggered)
        }

        return events.first { event in
            self.actions(forTarget: target, forControlEvent: event)?.contains(action.description) ?? false
        }
    }

    func isActionTerminal(_ action: Selector, to target: Any?) -> Bool {
        var nonTerminalEvents: [UIControl.Event] = [
            .touchDown, .touchDownRepeat, .touchDragInside, .touchDragOutside,
            .touchDragEnter, .editingDidBegin, .editingChanged,
        ]

#if !os(tvOS)
        switch self {
        case is UISlider, is UIStepper:
            nonTerminalEvents.append(.valueChanged)
        default:
            break
        }
#endif

        for event in nonTerminalEvents {
            if let actions = self.actions(forTarget: target, forControlEvent: event) {
                if actions.contains(where: { $0 == action.description }) {
                    return false
                }
            }
        }

        return true
    }
}

extension UIControl.Event {
    var description: String {
        if UIControl.Event.allTouchEvents.contains(self) {
            return "Touch"
        } else if UIControl.Event.allEditingEvents.contains(self) {
            return "Edit"
        } else if self == .valueChanged {
            return "Value Change"
        } else if self == .primaryActionTriggered {
            return "Primary Action"
        } else if #available(iOS 14.0, *), self == .menuActionTriggered {
            return "Menu Action"
        }
        return ""
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

protocol Titled {
    var amp_title: String? { get }
}

extension UIView: Titled {
    @objc var amp_title: String? { nil }
}

extension UIButton {
    override var amp_title: String? { currentTitle }
}

extension UISegmentedControl {
    override var amp_title: String? { titleForSegment(at: selectedSegmentIndex) }
}

#if !os(tvOS)
@available(iOS 14.0, *)
extension UIColorWell {
    override var amp_title: String? { title }
}
#endif

#endif
