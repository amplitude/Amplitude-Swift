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
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(windowDidBecomeKey), name: UIWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(UIKitUserInteractions.self, selector: #selector(windowDidResignKey), name: UIWindow.didResignKeyNotification, object: nil)
    }()

    private static let setupMethodSwizzling: Void = {
        swizzleMethod(UIApplication.self, from: #selector(UIApplication.sendAction), to: #selector(UIApplication.amp_sendAction))
        swizzleMethod(UIGestureRecognizer.self, from: #selector(setter: UIGestureRecognizer.state), to: #selector(UIGestureRecognizer.amp_setState))
    }()

    private static let setupAXBundle: Bool = {
        guard
            let axBundleURL = Bundle(identifier: "com.apple.UIKit")?
                .bundleURL
                .deletingLastPathComponent() // Remove "UIKit.framework"
                .deletingLastPathComponent() // Remove "Frameworks"
                .appendingPathComponent("AccessibilityBundles/UIKit.axbundle"),
            let axBundle = Bundle(url: axBundleURL),
            axBundle.load()
        else {
            return false
        }
        return true
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

    @objc static func windowDidBecomeKey(_ notification: NSNotification) {
        guard setupAXBundle, let window = notification.object as? UIWindow else { return }

        let swiftUIGestureRecognizer = _AmplitudeSwiftUIGestureRecognizer(target: UIKitUserInteractions.self, action: #selector(handleTap))
        swiftUIGestureRecognizer.cancelsTouchesInView = false
        swiftUIGestureRecognizer.delaysTouchesEnded = false
        swiftUIGestureRecognizer.delegate = window

        window.addGestureRecognizer(swiftUIGestureRecognizer)
    }

    @objc static func windowDidResignKey(_ notification: NSNotification) {
        guard setupAXBundle,
            let window = notification.object as? UIWindow,
            let swiftUIGestureRecognizer = window.gestureRecognizers?.first(where: { $0 is _AmplitudeSwiftUIGestureRecognizer })
        else { return }

        window.removeGestureRecognizer(swiftUIGestureRecognizer)
    }

    @objc static func handleTap(_ sender: UIGestureRecognizer) {
        if let target = findTargetUnderTap(for: sender) {
            let userInteractionEvent = target.eventFromData(with: "Tap")

            UIKitUserInteractions.amplitudeInstances.allObjects.forEach {
                $0.track(event: userInteractionEvent)
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

    private static let accessibilityHierarchyParser = UIKitAccessibilityHierarchyParser()

    private static func findTargetUnderTap(for gestureRecognizer: UIGestureRecognizer) -> AccessibilityTarget? {
        guard let view = gestureRecognizer.view else { return nil }

        let tapLocation = gestureRecognizer.location(in: nil)

        guard let target = accessibilityHierarchyParser.parseAccessibilityElement(on: tapLocation, in: view) else { return nil }

        if let targetView = target.object as? UIView, let control = targetView.controlInHierarchy, !control.allControlEvents.isEmpty {
            return nil
        }

        return target
    }
}

private class _AmplitudeSwiftUIGestureRecognizer: UITapGestureRecognizer {}

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

        guard state == .ended, let view, !(self is _AmplitudeSwiftUIGestureRecognizer) else { return }

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

extension AccessibilityTarget {
    func eventFromData(with action: String) -> UserInteractionEvent {
        if let view = object as? UIView {
            let viewData = view.extractData(with: action)
            return UserInteractionEvent(
                viewController: viewData.viewController,
                title: viewData.title,
                accessibilityLabel: label,
                action: action,
                targetViewClass: viewData.targetViewClass,
                targetText: viewData.targetText,
                hierarchy: viewData.hierarchy,
                targetType: type.stringify())
        } else {
            return UserInteractionEvent(
                accessibilityLabel: label,
                action: action,
                targetType: type.stringify())
        }
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

extension UIWindow: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
}

extension UIView {
    var controlInHierarchy: UIControl? {
        self as? UIControl ?? superview?.controlInHierarchy
    }
}

extension UIAccessibilityTraits {
    func stringify() -> String? {
        switch self {
        case .button:
            return "Button"
        case .link:
            return "Link"
        case .image:
            return "Image"
        case .searchField:
            return "Search Field"
        case .keyboardKey:
            return "Keyboard Key"
        case .staticText:
            return "Static Text"
        case .header:
            return "Header"
        case .tabBar:
            return "Tab Bar"
        default:
            break
        }

        if #available(iOS 17.0, tvOS 17.0, macCatalyst 17.0, *), self == .toggleButton {
            return "Toggle Button"
        }

        return nil
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
