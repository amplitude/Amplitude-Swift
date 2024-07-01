#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

// MARK: File-private Variables

private var globalUIPressGestureRecognizer: GlobalUIPressGestureRecognizer?
private var globalUISlideGestureRecognizer: GlobalUISlideGestureRecognizer?
private var globalUITextFieldGestureRecognizer: GlobalUITextFieldGestureRecognizer?

// MARK: -

internal final class UserInteractionCaptureDelegate {

    // MARK: - Properties

    weak var amplitude: Amplitude?

    /// The ket window of the application represented as a `UIView` element.
    var keyWindow: UIView? {
        guard
            let windowScene = applicationHandler()?.connectedScenes.first as? UIWindowScene,
            let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            return nil
        }
        return keyWindow
    }

    /// The accessibility targets within `keyWindow`.
    var accessibilityTargets: [AccessibilityTarget] {
        guard let keyWindow else { return [] }
        return accessibilityHierarchyParser.parseAccessibilityElements(in: keyWindow)
    }

    // MARK: - Private Properties

    private var applicationHandler: () -> UIApplication?

    private let accessibilityHierarchyParser = AccessibilityHierarchyParser()

    // MARK: - Life Cycle

    init(_ amplitude: Amplitude, with handler: @escaping () -> UIApplication?) {
        self.amplitude = amplitude
        self.applicationHandler = handler

        globalUIPressGestureRecognizer = GlobalUIPressGestureRecognizer(for: { [weak self] in self })
        globalUISlideGestureRecognizer = GlobalUISlideGestureRecognizer(for: { [weak self] in self })
        globalUITextFieldGestureRecognizer = GlobalUITextFieldGestureRecognizer(for: { [weak self] in self })

        UIApplication.swizzle
        setupAXBundle()
    }

    // MARK: - Private Methods

    private func setupAXBundle() {
        // Load UIKit accessibility bundle (UIKit.axbundle). This enables accessibility
        // metadata initialization, required for autocapture of UI element semantics.
        guard
            let axBundleURL = Bundle(identifier: "com.apple.UIKit")?
                .bundleURL
                .deletingLastPathComponent() // Remove "UIKit.framework"
                .deletingLastPathComponent() // Remove "Frameworks"
                .appendingPathComponent("AccessibilityBundles/UIKit.axbundle"),
            let axBundle = Bundle(url: axBundleURL),
            axBundle.load()
        else {
            amplitude?.logger?.error(message: "User interactions capture is not enabled. Accessibility bundle for UIKit was not loaded.")
            return
        }
    }
}

// MARK: -

fileprivate extension UIApplication {

    // MARK: - Private Properties

    static let swizzle: Void = {
        let applicationCls = UIApplication.self

        let originalSelector = #selector(sendEvent)
        let swizzledSelector = #selector(swizzled_sendEvent)

        guard
            let originalMethod = class_getInstanceMethod(applicationCls, originalSelector),
            let swizzledMethod = class_getInstanceMethod(applicationCls, swizzledSelector)
        else {
            return
        }

        let didAddMethod = class_addMethod(
            applicationCls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod))

        if didAddMethod {
            class_replaceMethod(
                applicationCls,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()

    // MARK: - Swizzled Methods

    @objc dynamic func swizzled_sendEvent(_ event: UIEvent) {
        swizzled_sendEvent(event)

        guard
            let touches = event.allTouches,
            let touch = touches.first
        else {
            return
        }

        switch touch.phase {
        case .began:
            handleTouchesBegan(touches, with: event)
        case .ended:
            handleTouchesEnded(touches, with: event)
        case .cancelled:
            handleTouchesCancelled(touches, with: event)
        case .moved:
            handleTouchesCancelled(touches, with: event)
        default:
            break
        }
    }

    // MARK: - Private Methods

    private func handleTouchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        globalUIPressGestureRecognizer?.touchesBegan(touches, with: event)
        globalUISlideGestureRecognizer?.touchesBegan(touches, with: event)
        globalUITextFieldGestureRecognizer?.touchesBegan(touches, with: event)
    }

    private func handleTouchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        globalUIPressGestureRecognizer?.touchesEnded(touches, with: event)
        globalUISlideGestureRecognizer?.touchesEnded(touches, with: event)
        globalUITextFieldGestureRecognizer?.touchesEnded(touches, with: event)
    }

    private func handleTouchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        globalUIPressGestureRecognizer?.touchesCancelled(touches, with: event)
        globalUISlideGestureRecognizer?.touchesCancelled(touches, with: event)
        globalUITextFieldGestureRecognizer?.touchesCancelled(touches, with: event)
    }

    private func handleTouchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        globalUIPressGestureRecognizer?.touchesMoved(touches, with: event)
        globalUISlideGestureRecognizer?.touchesMoved(touches, with: event)
        globalUITextFieldGestureRecognizer?.touchesMoved(touches, with: event)
    }
}

#endif
