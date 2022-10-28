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
    case US = "US"
    case EU = "EU"
}

public struct Constants {
    let SDK_LIBRARY = "amplitude-swift"
    let DEFAULT_API_HOST = "https://api2.amplitude.com/2/httpapi"
    let EU_DEFAULT_API_HOST = "https://api.eu.amplitude.com/2/httpapi"
    let BATCH_API_HOST = "https://api2.amplitude.com/batch"
    let EU_BATCH_API_HOST = "https://api.eu.amplitude.com/batch"
    let IDENTIFY_EVENT = "$identify"
    let GROUP_IDENTIFY_EVENT = "$groupidentify"
    let AMP_REVENUE_EVENT = "revenue_amount"
    let MAX_PROPERTY_KEYS = 1024
    let MAX_STRING_LENGTH = 1024
}
