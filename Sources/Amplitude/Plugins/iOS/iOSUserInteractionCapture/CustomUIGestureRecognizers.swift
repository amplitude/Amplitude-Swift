#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

import UIKit

internal final class GlobalUITextFieldGestureRecognizer: UIGestureRecognizer {

    // MARK: - Private Properties

    /// The delegate that manages user interactions options.
    private var captureDelegateHandler: () -> UserInteractionCaptureDelegate?

    /// A list of `UITextFieldDelegate`s to hold a reference to the wrappers.
    ///
    /// This avoids immediate deallocation since the delegate property of `UITextField`
    /// is a weak.
    private var delegates = [UITextFieldDelegate]()

    // MARK: - Life Cycle

    init(for captureDelegateHandler: @escaping () -> UserInteractionCaptureDelegate?) {
        self.captureDelegateHandler = captureDelegateHandler
        super.init(target: nil, action: nil)
    }

    // MARK: - Overridden Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard
            let captureDelegate = captureDelegateHandler()
        else {
            return
        }

        guard
            let initialTouchLocation = touches.first?.location(in: captureDelegate.keyWindow),
            let target = captureDelegate.accessibilityTargets.first(where: {
                $0.shape.contains(initialTouchLocation)
            }),
            let textField = target.object as? UITextField,
            let originalDelegate = textField.delegate,
            !(originalDelegate is TextFieldDelegateWrapper)
        else {
            return
        }

        let delegateWrapper = TextFieldDelegateWrapper(captureDelegate, originalDelegate, accessibilityTarget: target)
        delegates.append(delegateWrapper)
        textField.delegate = delegateWrapper
    }
}

// MARK: -

internal final class GlobalUISlideGestureRecognizer: UIGestureRecognizer {

    // MARK: - Private Properties

    /// The minimum slide amount in pixels to detect a slide movement.
    private static let minimumSlideAmount: Float = 0.01

    /// The delegate that manages user interactions options.
    private var captureDelegateHandler: () -> UserInteractionCaptureDelegate?

    /// The target element when the screen was first touched.
    private var initialTarget: AccessibilityTarget?

    /// The value of the target element when the screen was first touched.
    private var initialValue: Float?

    // MARK: - Life Cycle

    init(for captureDelegateHandler: @escaping () -> UserInteractionCaptureDelegate?) {
        self.captureDelegateHandler = captureDelegateHandler
        super.init(target: nil, action: nil)
    }

    // MARK: - Overridden Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard
            let captureDelegate = captureDelegateHandler()
        else {
            return
        }

        guard
            let initialTouchLocation = touches.first?.location(in: captureDelegate.keyWindow)
        else {
            return
        }

        // The target of an interaction is the underlying target behind the
        // first point when a touch begins since a slider could be modified
        // even when the final touch point is outside of its bounds.
        if let target = captureDelegate.accessibilityTargets.first(where: {
            $0.shape.contains(initialTouchLocation) &&
            $0.type.contains(.adjustable)
        }),
           let slider = target.object as? UISlider
        {
            initialTarget = target
            initialValue = slider.value
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard
            let captureDelegate = captureDelegateHandler()
        else {
            return
        }

        defer {
            self.initialTarget = nil
            self.initialValue = .zero
        }

        guard
            let initialTarget,
            let initialValue,
            let slider = initialTarget.object as? UISlider,
            slider.value != initialValue,
            abs(initialValue - slider.value) >= GlobalUISlideGestureRecognizer.minimumSlideAmount
        else {
            return
        }

        let percentage = Int(round(slider.value * 100))

        captureDelegate.amplitude?.track(event: UserInteractionEvent(
            .sliderChanged(to: percentage),
            label: initialTarget.label,
            value: initialTarget.value,
            type: initialTarget.type))
    }
}

// MARK: -

internal final class GlobalUIPressGestureRecognizer: UIGestureRecognizer {

    // MARK: - Private Properties

    /// The activation delta between the initial touch point and the final touch point.
    private static let pressActivationDelta: Double = 10

    /// The minimum press duration to detect a long press.
    private static let minimumPressDuration: TimeInterval = 0.5

    /// The number of clicks required to classify the followed clicks as rage clicks during
    /// the `rageClickTimeWindow` period.
    private static let rageClickCountThreshold = 5

    /// The time window to detect rage clicks.
    private static let rageClickTimeWindow: TimeInterval = 0.8

    /// The delegate that manages user interactions options.
    private var captureDelegateHandler: () -> UserInteractionCaptureDelegate?

    /// The target element when the screen was first touched.
    private var initialTarget: AccessibilityTarget?

    /// The root view of the screen when it was first touched.
    private var initialRootView: UIView?

    /// The initial point where the scroll gesture began.
    private var initialTouchLocation: CGPoint?

    /// The start time of the press gesture.
    private var startTime: TimeInterval?

    /// Specifies whether the followed clicks are rage clicks.
    private var isRageClicking = false

    /// The element targetted by a series of rage clicks.
    private var currentRageClickTarget: NSObject?

    /// Recent taps and the corresponding time associated with the tap.
    private var recentTaps: [(target: AccessibilityTarget, time: TimeInterval)] = []

    // MARK: - Life Cycle

    init(for captureDelegateHandler: @escaping () -> UserInteractionCaptureDelegate?) {
        self.captureDelegateHandler = captureDelegateHandler
        super.init(target: nil, action: nil)
    }

    // MARK: - Overridden Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard
            let captureDelegate = captureDelegateHandler()
        else {
            return
        }

        initialTouchLocation = touches.first?.location(in: captureDelegate.keyWindow)
        initialRootView = captureDelegate.keyWindow
        startTime = Date().timeIntervalSince1970

        if let initialTouchLocation,
           let target = captureDelegate.accessibilityTargets.first(where: {
            $0.shape.contains(initialTouchLocation) &&
            ($0.type.contains(.button) || $0.type.contains(.link))
        }) {
            initialTarget = target
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard
            let captureDelegate = captureDelegateHandler()
        else {
            return
        }

        defer {
            self.initialTarget = nil
        }

        guard
            let initialTouchLocation,
            let startTime,
            let initialTarget,
            let initialRootView,
            let endTouchLocation = touches.first?.location(in: initialRootView),
            abs(endTouchLocation.x - initialTouchLocation.x) <= GlobalUIPressGestureRecognizer.pressActivationDelta,
            abs(endTouchLocation.y - initialTouchLocation.y) <= GlobalUIPressGestureRecognizer.pressActivationDelta
        else {
            return
        }

        let endTime = Date().timeIntervalSince1970
        let pressDuration = endTime - startTime

        recentTaps.append((initialTarget, endTime))
        recentTaps = recentTaps.filter { endTime - $0.time <= GlobalUIPressGestureRecognizer.rageClickTimeWindow }

        // A series of continues rage clicks will be eliminated if the frequency of the clicks is higher
        // than the threshold within the specified interval. This means that when a rage click is detected,
        // consequent highly frequent clicks on the same element will not be tracked.
        if recentTaps.count >= GlobalUIPressGestureRecognizer.rageClickCountThreshold {
            if !isRageClicking {
                currentRageClickTarget = initialTarget.object
                isRageClicking = true
                trackClickRaged()

            } else if initialTarget.object !== currentRageClickTarget {
                currentRageClickTarget = nil
                isRageClicking = false
                recentTaps.removeAll()
                trackClickNotRaged()
            }
        } else {
            if isRageClicking {
                currentRageClickTarget = nil
                isRageClicking = false

            } else {
                trackClickNotRaged()
            }
        }

        func trackClickNotRaged() {
            var dead = false
            var longPress = false

            if initialTarget.type.contains(.notEnabled) {
                dead = true
            }

            if pressDuration >= GlobalUIPressGestureRecognizer.minimumPressDuration {
                longPress = true
            }

            captureDelegate.amplitude?.track(event: UserInteractionEvent(
                {
                    if dead && longPress {
                        return .longPress(dead: true)
                    } else if dead {
                        return .tap(dead: true)
                    } else if longPress {
                        return .longPress()
                    }
                    return .tap()
                }(),
                label: initialTarget.label,
                value: initialTarget.value,
                type: initialTarget.type))
        }

        func trackClickRaged() {
            captureDelegate.amplitude?.track(event: UserInteractionEvent(
                .rageTap,
                label: initialTarget.label,
                value: initialTarget.value,
                type: initialTarget.type))
        }
    }
}

#endif
