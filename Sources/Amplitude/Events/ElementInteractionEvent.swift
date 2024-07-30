import Foundation

public class ElementInteractionEvent: BaseEvent {
    convenience init(
        viewController: String? = nil,
        title: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: String,
        targetViewClass: String,
        targetText: String? = nil,
        hierarchy: String,
        actionMethod: String? = nil,
        gestureRecognizer: String? = nil
    ) {
        self.init(eventType: Constants.AMP_ELEMENT_INTERACTED_EVENT, eventProperties: [
            Constants.AMP_APP_VIEW_CONTROLLER: viewController,
            Constants.AMP_APP_TITLE: title,
            Constants.AMP_APP_TARGET_ACCESSIBILITY_LABEL: accessibilityLabel,
            Constants.AMP_APP_TARGET_ACCESSIBILITY_IDENTIFIER: accessibilityIdentifier,
            Constants.AMP_APP_ACTION: action,
            Constants.AMP_APP_TARGET_VIEW_CLASS: targetViewClass,
            Constants.AMP_APP_TARGET_TEXT: targetText,
            Constants.AMP_APP_HIERARCHY: hierarchy,
            Constants.AMP_APP_ACTION_METHOD: actionMethod,
            Constants.AMP_APP_GESTURE_RECOGNIZER: gestureRecognizer
        ])
    }
}
