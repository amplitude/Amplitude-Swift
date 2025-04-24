//
//  NetworkErrorEvent.swift
//  Amplitude-Swift
//
//  Created by Jin Xu on 3/17/25.
//

import Foundation

public class NetworkRequestEvent: BaseEvent {
    convenience init(url: URL,
                     method: String,
                     statusCode: Int?,
                     error: Error?,
                     startTime: Int64?,
                     completionTime: Int64?,
                     requestBodySize: Int64? = nil,
                     responseBodySize: Int64? = nil
    ) {

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let query = components?.query
        let fragment = components?.fragment
        components?.query = nil
        components?.fragment = nil
        if components?.user != nil {
            components?.user = "[mask]"
        }
        if components?.password != nil {
            components?.password = "[mask]"
        }
        let url = components?.url ?? url

        var eventProperties: [String: Any] = [Constants.AMP_NETWORK_URL_PROPERTY: url.absoluteString,
                                              Constants.AMP_NETWORK_REQUEST_METHOD_PROPERTY: method]
        eventProperties[Constants.AMP_NETWORK_STATUS_CODE_PROPERTY] = statusCode
        eventProperties[Constants.AMP_NETWORK_URL_QUERY_PROPERTY] = query
        eventProperties[Constants.AMP_NETWORK_URL_FRAGMENT_PROPERTY] = fragment
        if let error = error as? NSError {
            eventProperties[Constants.AMP_NETWORK_ERROR_CODE_PROPERTY] = error.code
            eventProperties[Constants.AMP_NETWORK_ERROR_MESSAGE_PROPERTY] = error.localizedDescription
        }
        eventProperties[Constants.AMP_NETWORK_START_TIME_PROPERTY] = startTime
        eventProperties[Constants.AMP_NETWORK_COMPLETION_TIME_PROPERTY] = completionTime
        if let completionTime = completionTime, let startTime = startTime {
            eventProperties[Constants.AMP_NETWORK_DURATION_PROPERTY] = completionTime - startTime
        }
        eventProperties[Constants.AMP_NETWORK_REQUEST_BODY_SIZE_PROPERTY] = requestBodySize
        eventProperties[Constants.AMP_NETWORK_RESPONSE_BODY_SIZE_PROPERTY] = responseBodySize
        self.init(eventType: Constants.AMP_NETWORK_TRACKING_EVENT, eventProperties: eventProperties)
    }
}
