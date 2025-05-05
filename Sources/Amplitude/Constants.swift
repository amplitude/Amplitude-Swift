//
//  Constants.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

@objc(AMPLogLevel)
public enum LogLevelEnum: Int {
    case OFF
    case ERROR
    case WARN
    case LOG
    case DEBUG
}

@objc(AMPServerZone)
public enum ServerZone: Int {
    case US
    case EU

    public typealias RawValue = String

    public var rawValue: RawValue {
        switch self {
        case .US:
            return "US"
        case .EU:
            return "EU"
        }
    }

    public init?(rawValue: RawValue) {
        switch rawValue {
        case "US":
            self = .US
        case "EU":
            self = .EU
        default:
            return nil
        }
    }
}

public struct Constants {
    static let SDK_LIBRARY = "amplitude-swift"
    static let SDK_VERSION = "1.12.1"
    public static let DEFAULT_API_HOST = "https://api2.amplitude.com/2/httpapi"
    public static let EU_DEFAULT_API_HOST = "https://api.eu.amplitude.com/2/httpapi"
    static let BATCH_API_HOST = "https://api2.amplitude.com/batch"
    static let EU_BATCH_API_HOST = "https://api.eu.amplitude.com/batch"
    static let IDENTIFY_EVENT = "$identify"
    static let GROUP_IDENTIFY_EVENT = "$groupidentify"
    static let MAX_PROPERTY_KEYS = 1024
    static let MAX_STRING_LENGTH = 1024
    public static let MIN_IDENTIFY_BATCH_INTERVAL_MILLIS = 30 * 1000  // 30s

    static let AMP_TRACKING_OPTION_CARRIER = "carrier"
    static let AMP_TRACKING_OPTION_CITY = "city"
    static let AMP_TRACKING_OPTION_COUNTRY = "country"
    static let AMP_TRACKING_OPTION_DEVICE_MANUFACTURER = "device_manufacturer"
    static let AMP_TRACKING_OPTION_DEVICE_MODEL = "device_model"
    static let AMP_TRACKING_OPTION_DMA = "dma"
    static let AMP_TRACKING_OPTION_IDFA = "idfa"
    static let AMP_TRACKING_OPTION_IDFV = "idfv"
    static let AMP_TRACKING_OPTION_IP_ADDRESS = "ip_address"
    static let AMP_TRACKING_OPTION_LANGUAGE = "language"
    static let AMP_TRACKING_OPTION_OS_NAME = "os_name"
    static let AMP_TRACKING_OPTION_OS_VERSION = "os_version"
    static let AMP_TRACKING_OPTION_PLATFORM = "platform"
    static let AMP_TRACKING_OPTION_REGION = "region"
    static let AMP_TRACKING_OPTION_VERSION_NAME = "version_name"

    static let AMP_AMPLITUDE_PREFIX = "[Amplitude] "

    static let AMP_SESSION_END_EVENT = "session_end"
    static let AMP_SESSION_START_EVENT = "session_start"
    static let AMP_APPLICATION_INSTALLED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Application Installed"
    static let AMP_APPLICATION_UPDATED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Application Updated"
    static let AMP_APPLICATION_OPENED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Application Opened"
    static let AMP_APPLICATION_BACKGROUNDED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Application Backgrounded"
    static let AMP_DEEP_LINK_OPENED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Deep Link Opened"
    static let AMP_SCREEN_VIEWED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Screen Viewed"
    static let AMP_ELEMENT_INTERACTED_EVENT = "\(AMP_AMPLITUDE_PREFIX)Element Interacted"
    static let AMP_NETWORK_TRACKING_EVENT = "\(AMP_AMPLITUDE_PREFIX)Network Tracking"

    static let AMP_REVENUE_EVENT = "revenue_amount"

    static let AMP_APP_VERSION_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Version"
    static let AMP_APP_BUILD_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Build"
    static let AMP_APP_PREVIOUS_VERSION_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Previous Version"
    static let AMP_APP_PREVIOUS_BUILD_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Previous Build"
    static let AMP_APP_FROM_BACKGROUND_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)From Background"
    static let AMP_APP_LINK_URL_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Link URL"
    static let AMP_APP_LINK_REFERRER_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Link Referrer"
    static let AMP_APP_SCREEN_NAME_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Screen Name"
    static let AMP_APP_TARGET_AXLABEL_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Target Accessibility Label"
    static let AMP_APP_TARGET_AXIDENTIFIER_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Target Accessibility Identifier"
    static let AMP_APP_ACTION_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Action"
    static let AMP_APP_TARGET_VIEW_CLASS_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Target View Class"
    static let AMP_APP_TARGET_TEXT_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Target Text"
    static let AMP_APP_HIERARCHY_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Hierarchy"
    static let AMP_APP_ACTION_METHOD_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Action Method"
    static let AMP_APP_GESTURE_RECOGNIZER_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Gesture Recognizer"

    static let AMP_NETWORK_URL_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)URL"
    static let AMP_NETWORK_URL_QUERY_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)URL Query"
    static let AMP_NETWORK_URL_FRAGMENT_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)URL Fragment"
    static let AMP_NETWORK_REQUEST_METHOD_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Request Method"
    static let AMP_NETWORK_STATUS_CODE_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Status Code"
    static let AMP_NETWORK_ERROR_CODE_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Error Code"
    static let AMP_NETWORK_ERROR_MESSAGE_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Error Message"
    static let AMP_NETWORK_START_TIME_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Start Time"
    static let AMP_NETWORK_COMPLETION_TIME_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Completion Time"
    static let AMP_NETWORK_DURATION_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Duration"
    static let AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Request Body Size"
    static let AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY = "\(AMP_AMPLITUDE_PREFIX)Response Body Size"

    public struct Configuration {
        public static let FLUSH_QUEUE_SIZE = 30
        public static let FLUSH_INTERVAL_MILLIS = 30 * 1000  // 30s
        public static let DEFAULT_INSTANCE = "$default_instance"
        public static let FLUSH_MAX_RETRIES = 6
        public static let MIN_TIME_BETWEEN_SESSIONS_MILLIS = 300000
        public static let IDENTIFY_BATCH_INTERVAL_MILLIS = 30 * 1000  // 30s
    }

    public struct Storage {
        public static let STORAGE_PREFIX = "amplitude-swift"
    }
}
