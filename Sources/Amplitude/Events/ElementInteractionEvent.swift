import Foundation

public class ElementInteractionEvent: BaseEvent {
    convenience init(
        screenName: String? = nil,
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
            Constants.AMP_APP_SCREEN_NAME_PROPERTY: screenName,
            Constants.AMP_APP_TITLE_PROPERTY: title,
            Constants.AMP_APP_TARGET_AXLABEL_PROPERTY: accessibilityLabel,
            Constants.AMP_APP_TARGET_AXIDENTIFIER_PROPERTY: accessibilityIdentifier,
            Constants.AMP_APP_ACTION_PROPERTY: action,
            Constants.AMP_APP_TARGET_VIEW_CLASS_PROPERTY: targetViewClass,
            Constants.AMP_APP_TARGET_TEXT_PROPERTY: targetText,
            Constants.AMP_APP_HIERARCHY_PROPERTY: hierarchy,
            Constants.AMP_APP_ACTION_METHOD_PROPERTY: actionMethod,
            Constants.AMP_APP_GESTURE_RECOGNIZER_PROPERTY: gestureRecognizer
        ])
    }
}
