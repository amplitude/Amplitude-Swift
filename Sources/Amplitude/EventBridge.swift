//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

struct Event {
    var eventType: String
    var eventProperties: [String: Any]? = nil
    var userProperties: [String: Any]? = nil
    var groups: [String: Any]? = nil
    var groupProperties: [String: Any]? = nil
}

enum EventChannel {
    
}

protocol EventReceiver {
    func receive(channel: EventChannel, event: Event)
}


protocol EventBridgable {
    func sendEvent(channel: EventChannel, event: Event)
    func setReceiver(channel: EventChannel, receiver: EventReceiver)
}

class EventBridge: EventBridgable {
    func sendEvent(channel: EventChannel, event: Event) {
        <#code#>
    }
    
    func setReceiver(channel: EventChannel, receiver: EventReceiver) {
        <#code#>
    }
}
