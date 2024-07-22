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

        fileprivate func userInteractionEvent(for actionsRepresentation: String) -> UserInteractionEvent {
            return UserInteractionEvent(
                viewController: viewController,
                title: title,
                accessibilityLabel: accessibilityLabel,
                accessibilityIdentifier: accessibilityIdentifier,
                action: actionsRepresentation,
                targetViewClass: targetViewClass,
                targetText: targetText,
                hierarchy: hierarchy
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

    // MARK: Coalesce logically continuous events

    private class CoalescedEvent {
        let controlId: ObjectIdentifier

        let eventData: UIKitUserInteractions.EventData

        var terminated = false

        private(set) var actions = [Selector]()

        init(_ eventData: UIKitUserInteractions.EventData, to target: Any?, from control: UIControl, initial action: Selector) {
            self.controlId = ObjectIdentifier(control)
            self.eventData = eventData
            addAction(action, to: target, from: control)
        }

        func addAction(_ action: Selector, to target: Any?, from control: UIControl) {
            terminated = control.isActionTerminal(action, to: target)
            actions.append(action)
        }
    }

    private static let actionMethodsDelimiter = " "

    private static var coalesceTask: DispatchWorkItem?

    private static var coalescedEvents = [CoalescedEvent]()

    private func coalesceAction(_ action: Selector, to target: Any?, from control: UIControl) {
        let controlIdentifier = ObjectIdentifier(control)

        if let prevEvent = UIApplication.coalescedEvents.last {
            if prevEvent.controlId == controlIdentifier {
                if !prevEvent.actions.contains(action) {
                    prevEvent.addAction(action, to: target, from: control)
                }
            } else {
                prevEvent.terminated = true
                UIApplication.coalescedEvents.append(CoalescedEvent(control.eventData, to: target, from: control, initial: action))
            }
        } else {
            UIApplication.coalescedEvents.append(CoalescedEvent(control.eventData, to: target, from: control, initial: action))
        }

        UIApplication.coalesceTask?.cancel()

        let task = DispatchWorkItem {
            while UIApplication.coalescedEvents.first?.terminated ?? false {
                let coalescedEvent = UIApplication.coalescedEvents.removeFirst()

                let actions = coalescedEvent.actions.map { $0.description }.joined(separator: UIApplication.actionMethodsDelimiter)

                let userInteractionEvent = coalescedEvent.eventData.userInteractionEvent(for: actions)

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
        return view.eventData.userInteractionEvent(for: action)
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
    func isActionTerminal(_ action: Selector, to target: Any?) -> Bool {
        var nonTerminalEvents: [UIControl.Event] = [
            .touchDown,
            .touchDownRepeat,
            .touchDragInside,
            .touchDragOutside,
            .touchDragEnter,
            .editingDidBegin,
            .editingChanged,
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
