//
//  File.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

enum LogLevelEnum: Int {
    case DEBUG
    case LOG
    case WARN
    case ERROR
    case OFF
}

enum ServerZone: String {
    case US
    case EU
}

public struct Constants {
    static let SDK_LIBRARY = "amplitude-swift"
    static let DEFAULT_API_HOST = "https://api2.amplitude.com/2/httpapi"
    static let EU_DEFAULT_API_HOST = "https://api.eu.amplitude.com/2/httpapi"
    static let BATCH_API_HOST = "https://api2.amplitude.com/batch"
    static let EU_BATCH_API_HOST = "https://api.eu.amplitude.com/batch"
    static let IDENTIFY_EVENT = "$identify"
    static let GROUP_IDENTIFY_EVENT = "$groupidentify"
    static let AMP_REVENUE_EVENT = "revenue_amount"
    static let MAX_PROPERTY_KEYS = 1024
    static let MAX_STRING_LENGTH = 1024

    struct Configuration {
        static let FLUSH_QUEUE_SIZE = 30
        static let FLUSH_INTERVAL_MILLIS = 30 * 1000  // 30s
        static let DEFAULT_INSTANCE = "default_instance"
        static let FLUSH_MAX_RETRIES = 5
        static let MIN_TIME_BETWEEN_SESSIONS_MILLIS = 300000
    }
}
