//
//  DeadClickEvent.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 6/17/25.
//

import Foundation

public class DeadClickEvent: BaseEvent {
    convenience init(
        time: Date,
        x: Double? = nil,
        y: Double? = nil,
        screenName: String? = nil,
        accessibilityLabel: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: String,
        targetViewClass: String,
        targetText: String? = nil,
        hierarchy: String,
        actionMethod: String? = nil,
        gestureRecognizer: String? = nil
    ) {
        var eventProperties: [String: Any] = [:]
        eventProperties[Constants.AMP_COORDINATE_X] = x
        eventProperties[Constants.AMP_COORDINATE_Y] = y
        eventProperties[Constants.AMP_APP_SCREEN_NAME_PROPERTY] = screenName
        eventProperties[Constants.AMP_APP_TARGET_AXLABEL_PROPERTY] = accessibilityLabel
        eventProperties[Constants.AMP_APP_TARGET_AXIDENTIFIER_PROPERTY] = accessibilityIdentifier
        eventProperties[Constants.AMP_APP_ACTION_PROPERTY] = action
        eventProperties[Constants.AMP_APP_TARGET_VIEW_CLASS_PROPERTY] = targetViewClass
        eventProperties[Constants.AMP_APP_TARGET_TEXT_PROPERTY] = targetText
        eventProperties[Constants.AMP_APP_HIERARCHY_PROPERTY] = hierarchy
        eventProperties[Constants.AMP_APP_ACTION_METHOD_PROPERTY] = actionMethod
        eventProperties[Constants.AMP_APP_GESTURE_RECOGNIZER_PROPERTY] = gestureRecognizer

        self.init(timestamp: time.amp_timestamp(), eventType: Constants.AMP_DEAD_CLICK_EVENT, eventProperties: eventProperties)
    }
}
