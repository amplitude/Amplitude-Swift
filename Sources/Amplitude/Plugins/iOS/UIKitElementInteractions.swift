#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
import UIKit
import AmplitudeCore

class UIKitElementInteractions {
    struct EventData {
        enum Source {
            case actionMethod

            case gestureRecognizer
        }

        let screenName: String?

        let accessibilityLabel: String?

        let accessibilityIdentifier: String?

        let targetViewIdentifier: ObjectIdentifier

        let targetViewClass: String

        let targetText: String?

        let hierarchy: String

        fileprivate func elementInteractionEvent(for action: String, from source: Source? = nil, withName sourceName: String? = nil) -> ElementInteractionEvent {
            return ElementInteractionEvent(
                screenName: screenName,
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
    fileprivate static var rageClickDetectors: [ObjectIdentifier: RageClickDetector] = [:]
    fileprivate static var deadClickDetectors: [ObjectIdentifier: DeadClickDetector] = [:]
    fileprivate static let lock = NSLock()

    private static let addNotificationObservers: Void = {
        NotificationCenter.default.addObserver(UIKitElementInteractions.self, selector: #selector(didEndEditing), name: UITextField.textDidEndEditingNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitElementInteractions.self, selector: #selector(didEndEditing), name: UITextView.textDidEndEditingNotification, object: nil)
    }()

    private static let setupMethodSwizzling: Void = {
        swizzleMethod(UIApplication.self, from: #selector(UIApplication.sendAction), to: #selector(UIApplication.amp_sendAction))
        swizzleMethod(UIGestureRecognizer.self, from: #selector(setter: UIGestureRecognizer.state), to: #selector(UIGestureRecognizer.amp_setState))
    }()

    static func register(_ amplitude: Amplitude) {
        let manager = amplitude.autocaptureManager

        lock.withLock {
            amplitudeInstances.add(amplitude)
            let identifier = ObjectIdentifier(amplitude)
            let frustrationInteractions = manager.isEnabled(.frustrationInteractions)

            if frustrationInteractions, manager.rageClickEnabled {
                rageClickDetectors[identifier] = RageClickDetector(amplitude: amplitude)
            } else if let rageClickDetector = rageClickDetectors.removeValue(forKey: identifier) {
                rageClickDetector.reset()
            }

            if frustrationInteractions, manager.deadClickEnabled {
                deadClickDetectors[identifier] = DeadClickDetector(amplitude: amplitude)
            } else if let deadClickDetector = deadClickDetectors.removeValue(forKey: identifier) {
                deadClickDetector.reset()
            }
        }
        setupMethodSwizzling
        addNotificationObservers
    }

    static func unregister(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.remove(amplitude)
            let identifier = ObjectIdentifier(amplitude)

            if let rageClickDetector = rageClickDetectors.removeValue(forKey: identifier) {
                rageClickDetector.reset()
            }

            if let deadClickDetector = deadClickDetectors.removeValue(forKey: identifier) {
                deadClickDetector.reset()
            }
        }
    }

    @objc static func didEndEditing(_ notification: NSNotification) {
        guard let view = notification.object as? UIView else { return }
        // Text fields in SwiftUI are identifiable only after the text field is edited.

        // Track element interaction events only if .elementInteractions is enabled
        lock.withLock {
            for amplitude in amplitudeInstances.allObjects where amplitude.autocaptureManager.isEnabled(.elementInteractions) {
                let elementInteractionEvent = view.eventData.elementInteractionEvent(for: "didEndEditing")
                amplitude.track(event: elementInteractionEvent)
            }
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

    static func interfaceChangeProviderDidChange(for amplitude: Amplitude, from oldProvider: InterfaceSignalProvider?, to newProvider: InterfaceSignalProvider?) {
        lock.withLock {
            let identifier = ObjectIdentifier(amplitude)
            self.deadClickDetectors[identifier]?.interfaceSignalProviderDidChange(from: oldProvider, to: newProvider)
        }
    }

    private static let physicalTapDedupDistanceThreshold: CGFloat = 12
    private static let physicalTapDedupTimeThreshold: TimeInterval = 0.005
    private static var physicalTapDedupCandidates: [PhysicalTapDedupCandidate] = []

    private final class PhysicalTapDedupCandidate {
        weak var window: UIWindow?
        let location: CGPoint
        let timestamp: TimeInterval

        init(view: UIView, location: CGPoint, timestamp: TimeInterval) {
            self.window = view.window
            self.location = location
            self.timestamp = timestamp
        }
    }

    fileprivate static func processFrustrationInteractionForView(_ view: UIView,
                                                                 clickData: FrustrationClickData,
                                                                 includeRageClick: Bool,
                                                                 includeDeadClick: Bool) {
        lock.withLock {
            guard !isDuplicatePhysicalTap(view: view, location: clickData.location) else {
                return
            }

            for amplitude in amplitudeInstances.allObjects {
                let identifier = ObjectIdentifier(amplitude)

                // Check if rage click detector exists (enabled via remote config or local config)
                if includeRageClick, let rageClickDetector = rageClickDetectors[identifier] {
                    rageClickDetector.processClick(clickData)
                }

                // Check if dead click detector exists (enabled via remote config or local config)
                if includeDeadClick, let deadClickDetector = deadClickDetectors[identifier] {
                    deadClickDetector.processClick(clickData)
                }
            }
        }
    }

    static func isDuplicatePhysicalTap(view: UIView,
                                       location: CGPoint,
                                       timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        physicalTapDedupCandidates.removeAll { candidate in
            candidate.window == nil || timestamp - candidate.timestamp > physicalTapDedupTimeThreshold
        }

        let duplicate = physicalTapDedupCandidates.contains { candidate in
            guard isWithinPhysicalTapDedupDistance(candidate.location, location) else {
                return false
            }

            return isSameWindow(candidate.window, view.window)
        }

        if !duplicate {
            physicalTapDedupCandidates.append(PhysicalTapDedupCandidate(view: view, location: location, timestamp: timestamp))
        }

        return duplicate
    }

    private static func isWithinPhysicalTapDedupDistance(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
        return hypot(point1.x - point2.x, point1.y - point2.y) <= physicalTapDedupDistanceThreshold
    }

    private static func isSameWindow(_ window1: UIWindow?, _ window2: UIWindow?) -> Bool {
        guard let window1, let window2 else { return false }
        return window1 === window2
    }

    static func resetPhysicalTapDedupCandidates() {
        physicalTapDedupCandidates.removeAll()
    }
}

extension Configuration {
    var isRageClickEnabled: Bool {
        autocapture.contains(.frustrationInteractions) && interactionsOptions.rageClick.enabled
    }

    var isDeadClickEnabled: Bool {
        autocapture.contains(.frustrationInteractions) && interactionsOptions.deadClick.enabled
    }
}

extension UIApplication {
    @objc func amp_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let sendActionResult = amp_sendAction(action, to: target, from: sender, for: event)

        // TODO: Reduce SwiftUI noise by finding the unique view that the action method is attached to.
        // Currently, the action methods pointing to a SwiftUI target are blocked.
        let targetClass = String(cString: object_getClassName(target))
        if targetClass.contains("SwiftUI") {
            return sendActionResult
        }

        guard sendActionResult,
              let control = sender as? UIControl,
              control.amp_shouldTrack(action, for: target),
              let actionEvent = control.event(for: action, to: target)?.description
        else { return sendActionResult }

        // Track element interaction events only if .elementInteractions is enabled
        UIKitElementInteractions.lock.withLock {
            for amplitude in UIKitElementInteractions.amplitudeInstances.allObjects where amplitude.autocaptureManager.isEnabled(.elementInteractions) {
                let elementInteractionEvent = control.eventData.elementInteractionEvent(for: actionEvent, from: .actionMethod, withName: NSStringFromSelector(action))
                amplitude.track(event: elementInteractionEvent)
            }
        }

        let shouldProcessRageClick = !control.amp_ignoreRageClick
        let shouldProcessDeadClick = !control.amp_ignoreDeadClick

        if actionEvent == "touch", shouldProcessRageClick || shouldProcessDeadClick {
            var location = CGPoint.zero

            if let event = event, let touch = event.allTouches?.first {
                // For UIControl events, get location relative to the main window
                if let window = control.window {
                    location = touch.location(in: window)
                } else {
                    location = touch.location(in: control)
                }
            } else {
                // Fallback: use the center of the view in window coordinates
                if let window = control.window {
                    location = control.convert(control.bounds.amp_center, to: window)
                } else {
                    location = control.bounds.amp_center
                }
            }

            let clickData = FrustrationClickData(
                eventData: control.eventData,
                location: location,
                action: actionEvent,
                source: .actionMethod,
                sourceName: NSStringFromSelector(action)
            )

            UIKitElementInteractions.processFrustrationInteractionForView(
                control,
                clickData: clickData,
                includeRageClick: shouldProcessRageClick,
                includeDeadClick: shouldProcessDeadClick
            )
        }

        return sendActionResult
    }
}

extension UIGestureRecognizer {
    @objc func amp_setState(_ state: UIGestureRecognizer.State) {
        amp_setState(state)

        guard state == .ended, let view else { return }

        // Block scroll and zoom events for `UIScrollView`.
        if let scrollView = view as? UIScrollView {
            if self === scrollView.panGestureRecognizer {
                return
            }

#if !os(tvOS)
            if self === scrollView.pinchGestureRecognizer {
                return
            }
#endif
        }

        var isTap = false
        let gestureAction: String?
        switch self {
        case let tapGestureRecognizer as UITapGestureRecognizer:
            gestureAction = "tap"
#if !os(tvOS)
            isTap = tapGestureRecognizer.numberOfTapsRequired == 1 && tapGestureRecognizer.numberOfTouchesRequired == 1
#else
            isTap = tapGestureRecognizer.numberOfTapsRequired == 1
#endif
        case is UISwipeGestureRecognizer:
            gestureAction = "swipe"
        case is UIPanGestureRecognizer:
            gestureAction = "pan"
        case is UILongPressGestureRecognizer:
            gestureAction = "longPress"
#if !os(tvOS)
        case is UIPinchGestureRecognizer:
            gestureAction = "pinch"
        case is UIRotationGestureRecognizer:
            gestureAction = "rotation"
        case is UIHoverGestureRecognizer:
            gestureAction = nil
#endif
#if !os(tvOS) && !os(visionOS)
        case is UIScreenEdgePanGestureRecognizer:
            gestureAction = "screenEdgePan"
#endif
        default:
            if view is UIWindow {
                gestureAction = nil
            } else {
                gestureAction = String(describing: type(of: self))
            }
        }

        guard let gestureAction else { return }

        // Track element interaction events only if .elementInteractions is enabled
        UIKitElementInteractions.lock.withLock {
            for amplitude in UIKitElementInteractions.amplitudeInstances.allObjects where amplitude.autocaptureManager.isEnabled(.elementInteractions) {
                let elementInteractionEvent = view.eventData.elementInteractionEvent(for: gestureAction, from: .gestureRecognizer, withName: descriptiveTypeName)
                amplitude.track(event: elementInteractionEvent)
            }
        }

        let shouldProcessRageClick = !view.amp_ignoreRageClick
        let shouldProcessDeadClick = !view.amp_ignoreDeadClick

        if isTap, shouldProcessDeadClick || shouldProcessRageClick {
            let clickData = FrustrationClickData(
                eventData: view.eventData,
                location: location(in: nil),
                action: gestureAction,
                source: .gestureRecognizer,
                sourceName: descriptiveTypeName)

            UIKitElementInteractions.processFrustrationInteractionForView(
                view,
                clickData: clickData,
                includeRageClick: shouldProcessRageClick,
                includeDeadClick: shouldProcessDeadClick
            )
        }
    }
}

extension UIView {
    private static let viewHierarchyDelimiter = " → "

    var eventData: UIKitElementInteractions.EventData {
        return UIKitElementInteractions.EventData(
            screenName: owningViewController
                .flatMap(UIViewController.amp_topViewController)
                .flatMap(UIKitScreenViews.screenName),
            accessibilityLabel: accessibilityLabel,
            accessibilityIdentifier: accessibilityIdentifier,
            targetViewIdentifier: ObjectIdentifier(self),
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
            return "touch"
        } else if UIControl.Event.allEditingEvents.contains(self) {
            return "edit"
        } else if self == .valueChanged {
            return "valueChange"
        } else if self == .primaryActionTriggered {
            return "primaryAction"
        } else if #available(iOS 14.0, tvOS 14.0, macCatalyst 14.0, *), self == .menuActionTriggered {
            return "menuAction"
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
    override var amp_title: String? { currentTitle ?? currentImage?.accessibilityIdentifier }
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
