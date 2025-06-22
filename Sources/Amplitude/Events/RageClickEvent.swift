//
//  RageClickEvent.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 5/23/25.
//

import Foundation

public class RageClickEvent: BaseEvent {
    convenience init(
        /// The time of the click, ISO 8601 format of UTC.
        beginTime: Date,
        /// The time of the click, ISO 8601 format of UTC.
        endTime: Date,
        /// The clicks of the event.
        clicks: [Click]? = nil,
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
        eventProperties[Constants.AMP_APP_SCREEN_NAME_PROPERTY] = screenName
        eventProperties[Constants.AMP_APP_TARGET_AXLABEL_PROPERTY] = accessibilityLabel
        eventProperties[Constants.AMP_APP_TARGET_AXIDENTIFIER_PROPERTY] = accessibilityIdentifier
        eventProperties[Constants.AMP_APP_ACTION_PROPERTY] = action
        eventProperties[Constants.AMP_APP_TARGET_VIEW_CLASS_PROPERTY] = targetViewClass
        eventProperties[Constants.AMP_APP_TARGET_TEXT_PROPERTY] = targetText
        eventProperties[Constants.AMP_APP_HIERARCHY_PROPERTY] = hierarchy
        eventProperties[Constants.AMP_APP_ACTION_METHOD_PROPERTY] = actionMethod
        eventProperties[Constants.AMP_APP_GESTURE_RECOGNIZER_PROPERTY] = gestureRecognizer

        // Add rage click specific properties
        eventProperties[Constants.AMP_BEGIN_TIME_PROPERTY] = beginTime.amp_iso8601String()
        eventProperties[Constants.AMP_END_TIME_PROPERTY] = endTime.amp_iso8601String()
        let duration = endTime.timeIntervalSince(beginTime) * 1000 // Convert to milliseconds
        eventProperties[Constants.AMP_DURATION_PROPERTY] = duration
        eventProperties[Constants.AMP_CLICKS_PROPERTY] = clicks
        eventProperties[Constants.AMP_CLICK_COUNT_PROPERTY] = clicks?.count ?? 0

        self.init(timestamp: beginTime.amp_timestamp(), eventType: Constants.AMP_RAGE_CLICK_EVENT, eventProperties: eventProperties)
    }
}

public struct Click: Codable {
    /// The x-coordinate of the click in points, relative to the screen.
    public var x: Double?
    /// The y-coordinate of the click in points, relative to the screen.
    public var y: Double?
    /// The time of the click, ISO 8601 format of UTC.
    public var time: String?

    enum CodingKeys: String, CodingKey {
        case x = "X"
        case y = "Y"
        case time = "Time"
    }
}
