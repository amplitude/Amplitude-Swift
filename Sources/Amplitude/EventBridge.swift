//
//  EventBridge.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

struct Event {
    var eventType: String
    var eventProperties: [String: Any]?
    var userProperties: [String: Any]?
    var groups: [String: Any]?
    var groupProperties: [String: Any]?
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
    }

    func setReceiver(channel: EventChannel, receiver: EventReceiver) {
    }
}
