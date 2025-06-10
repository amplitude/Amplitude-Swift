#if (os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)) && !AMPLITUDE_DISABLE_UIKIT
import UIKit

class UIKitElementInteractions {
    struct EventData {
        enum Source {
            case actionMethod

            case gestureRecognizer
        }

        let screenName: String?

        let accessibilityLabel: String?

        let accessibilityIdentifier: String?

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
    
    struct RageClickData {
        let eventData: EventData
        let location: CGPoint
        let timestamp: Date
        let action: String
        let source: EventData.Source?
        let sourceName: String?
    }
    
    class RageClickDetector {
        private var clickQueue: [RageClickData] = []
        private var debounceTimer: Timer?
        private let lock = NSLock()
        private weak var amplitude: Amplitude?
        
        init(amplitude: Amplitude) {
            self.amplitude = amplitude
        }
        
        func processClick(_ clickData: RageClickData) {
            lock.withLock {
                let config = amplitude?.configuration.interactionsOptions.rageClick
                let threshold = config?.threshold ?? 3
                let timeoutMs = config?.timeout ?? 1000
                let timeoutInterval = TimeInterval(timeoutMs) / 1000.0
                
                // Filter out clicks that are too old or not on the same element
                let cutoffTime = clickData.timestamp.addingTimeInterval(-timeoutInterval)
                clickQueue = clickQueue.filter { existingClick in
                    existingClick.timestamp >= cutoffTime &&
                    isSameElement(existingClick.eventData, clickData.eventData) &&
                    isWithinRange(existingClick.location, clickData.location)
                }

                clickQueue.append(clickData)
                
                // Check if we have enough clicks for rage click
                if clickQueue.count >= threshold {
                    // Cancel existing timer and start new debounce
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: timeoutInterval, repeats: false) { [weak self] _ in
                        self?.triggerRageClick()
                    }
                }
            }
        }
        
        private func isSameElement(_ data1: EventData, _ data2: EventData) -> Bool {
            return data1.hierarchy == data2.hierarchy &&
                   data1.targetViewClass == data2.targetViewClass &&
                   data1.accessibilityIdentifier == data2.accessibilityIdentifier
        }
        
        private func isWithinRange(_ point1: CGPoint, _ point2: CGPoint) -> Bool {
            let distance = sqrt(pow(point1.x - point2.x, 2) + pow(point1.y - point2.y, 2))
            return distance <= 50.0
        }
        
        private func triggerRageClick() {
            lock.withLock {
                guard let amplitude = amplitude,
                      let firstClick = clickQueue.first,
                      let lastClick = clickQueue.last
                else { return }

                let clicks = clickQueue.map { clickData in
                    Click(
                        x: clickData.location.x,
                        y: clickData.location.y,
                        time: clickData.timestamp.amp_iso8601String()
                    )
                }
                
                let rageClickEvent = RageClickEvent(
                    beginTime: firstClick.timestamp,
                    endTime: lastClick.timestamp,
                    clicks: clicks,
                    screenName: firstClick.eventData.screenName,
                    accessibilityLabel: firstClick.eventData.accessibilityLabel,
                    accessibilityIdentifier: firstClick.eventData.accessibilityIdentifier,
                    action: firstClick.action,
                    targetViewClass: firstClick.eventData.targetViewClass,
                    targetText: firstClick.eventData.targetText,
                    hierarchy: firstClick.eventData.hierarchy,
                    actionMethod: firstClick.source == .actionMethod ? firstClick.sourceName : nil,
                    gestureRecognizer: firstClick.source == .gestureRecognizer ? firstClick.sourceName : nil
                )
                
                amplitude.track(event: rageClickEvent)

                clickQueue.removeAll()
            }
        }
        
        func reset() {
            lock.withLock {
                debounceTimer?.invalidate()
                debounceTimer = nil
                clickQueue.removeAll()
            }
        }
    }

    fileprivate static let amplitudeInstances = NSHashTable<Amplitude>.weakObjects()
    fileprivate static var rageClickDetectors: [ObjectIdentifier: RageClickDetector] = [:]

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
        lock.withLock {
            amplitudeInstances.add(amplitude)
            let identifier = ObjectIdentifier(amplitude)
            
            // Only create rage click detector if rage click detection is enabled
            if amplitude.configuration.autocapture.contains(.rageClick) {
                rageClickDetectors[identifier] = RageClickDetector(amplitude: amplitude)
            }
        }
        setupMethodSwizzling
        addNotificationObservers
    }

    static func unregister(_ amplitude: Amplitude) {
        lock.withLock {
            amplitudeInstances.remove(amplitude)
            let identifier = ObjectIdentifier(amplitude)
            rageClickDetectors[identifier]?.reset()
            rageClickDetectors.removeValue(forKey: identifier)
        }
    }
    
    fileprivate static func processRageClickForView(_ view: UIView, action: String, source: EventData.Source?, sourceName: String?, event: UIEvent?) {
        // Check if rage click detection is disabled for this view
        if view.amp_ignoreRageClick {
            return
        }
        
        // Get touch location
        var location = CGPoint.zero
        
        if let event = event, let touch = event.allTouches?.first {
            // For UIControl events, get location relative to the main window
            if let window = view.window {
                location = touch.location(in: window)
            } else {
                location = touch.location(in: view)
            }
        } else {
            // Fallback: use the center of the view in window coordinates
            if let window = view.window {
                location = view.convert(view.bounds.center, to: window)
            } else {
                location = view.bounds.center
            }
        }
        
        let clickData = RageClickData(
            eventData: view.eventData,
            location: location,
            timestamp: Date(),
            action: action,
            source: source,
            sourceName: sourceName
        )
        
        lock.withLock {
            for amplitude in amplitudeInstances.allObjects {
                // Check if rage click detection is enabled in autocapture options
                guard amplitude.configuration.autocapture.contains(.rageClick) else {
                    continue
                }
                
                let identifier = ObjectIdentifier(amplitude)
                rageClickDetectors[identifier]?.processClick(clickData)
            }
        }
    }

    @objc static func didEndEditing(_ notification: NSNotification) {
        guard let view = notification.object as? UIView else { return }
        // Text fields in SwiftUI are identifiable only after the text field is edited.
        
        // Track element interaction events only if .elementInteractions is enabled
        amplitudeInstances.allObjects.forEach { amplitude in
            if amplitude.configuration.autocapture.contains(.elementInteractions) {
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
        UIKitElementInteractions.amplitudeInstances.allObjects.forEach { amplitude in
            if amplitude.configuration.autocapture.contains(.elementInteractions) {
                let elementInteractionEvent = control.eventData.elementInteractionEvent(for: actionEvent, from: .actionMethod, withName: NSStringFromSelector(action))
                amplitude.track(event: elementInteractionEvent)
            }
        }
        
        // Process rage click detection for touch events if .rageClick is enabled
        if actionEvent == "touch" {
            UIKitElementInteractions.processRageClickForView(control, action: actionEvent, source: .actionMethod, sourceName: NSStringFromSelector(action), event: event)
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

        let gestureAction: String?
        switch self {
        case is UITapGestureRecognizer:
            gestureAction = "tap"
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
#endif
#if !os(tvOS) && !os(visionOS)
        case is UIScreenEdgePanGestureRecognizer:
            gestureAction = "screenEdgePan"
#endif
        default:
            gestureAction = nil
        }

        guard let gestureAction else { return }

        // Track element interaction events only if .elementInteractions is enabled
        UIKitElementInteractions.amplitudeInstances.allObjects.forEach { amplitude in
            if amplitude.configuration.autocapture.contains(.elementInteractions) {
                let elementInteractionEvent = view.eventData.elementInteractionEvent(for: gestureAction, from: .gestureRecognizer, withName: descriptiveTypeName)
                amplitude.track(event: elementInteractionEvent)
            }
        }
        
        // Process rage click detection for tap gestures if .rageClick is enabled
        if gestureAction == "tap" {
            // Get location from the gesture recognizer
            var location = CGPoint.zero
            if let window = view.window {
                location = self.location(in: window)
            } else {
                location = self.location(in: view)
            }
            
            let clickData = UIKitElementInteractions.RageClickData(
                eventData: view.eventData,
                location: location,
                timestamp: Date(),
                action: gestureAction,
                source: .gestureRecognizer,
                sourceName: descriptiveTypeName
            )
            
            UIKitElementInteractions.lock.withLock {
                for amplitude in UIKitElementInteractions.amplitudeInstances.allObjects {
                    // Check if rage click detection is enabled in autocapture options
                    guard amplitude.configuration.autocapture.contains(.rageClick) else {
                        continue
                    }
                    
                    let identifier = ObjectIdentifier(amplitude)
                    UIKitElementInteractions.rageClickDetectors[identifier]?.processClick(clickData)
                }
            }
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

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
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

// MARK: - Rage Click Ignore Extension
extension UIView {
    private static var amp_ignoreRageClickKey: UInt8 = 0
    
    /// Whether this view should be ignored for rage click detection
    var amp_ignoreRageClick: Bool {
        get {
            return objc_getAssociatedObject(self, &UIView.amp_ignoreRageClickKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &UIView.amp_ignoreRageClickKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Mark this view to be ignored for specific interaction events
    /// - Parameter rageClick: Whether to ignore rage click detection for this view
    @objc func amp_ignoreInteractionEvent(rageClick: Bool = false) {
        if rageClick {
            self.amp_ignoreRageClick = true
        }
    }
}

#endif
