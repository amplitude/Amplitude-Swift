//
//  GroupIdentifyEvent.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import Foundation

public class GroupIdentifyEvent: BaseEvent {
    override public var eventType: String {
        get {
            return "$groupidentify"
        }
        set {
        }
    }
}
