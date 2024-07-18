import Foundation

public class UserInteractionEvent: BaseEvent {
    convenience init(
        viewController: String? = nil,
        title: String? = nil,
        accessibilityLabel: String? = nil,
        action: String,
        targetViewClass: String? = nil,
        targetText: String? = nil,
        hierarchy: String? = nil,
        gestureRecognizer: String? = nil,
        targetType: String? = nil
    ) {
        self.init(eventType: Constants.AMP_USER_INTERACTION_EVENT, eventProperties: [
            Constants.AMP_APP_VIEW_CONTROLLER: viewController,
            Constants.AMP_APP_TITLE: title,
            Constants.AMP_APP_TARGET_ACCESSIBILITY_LABEL: accessibilityLabel,
            Constants.AMP_APP_ACTION: action,
            Constants.AMP_APP_TARGET_VIEW_CLASS: targetViewClass,
            Constants.AMP_APP_TARGET_TEXT: targetText,
            Constants.AMP_APP_HIERARCHY: hierarchy,
            Constants.AMP_APP_GESTURE_RECOGNIZER: gestureRecognizer,
            Constants.AMP_APP_TARGET_TYPE: targetType
        ])
    }
}
