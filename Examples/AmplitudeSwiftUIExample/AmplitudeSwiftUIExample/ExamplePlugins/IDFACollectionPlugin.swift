//
//  IDFACollectionPlugin.swift
//  
//
//  Created by Alyssa.Yu on 12/7/22.
//

// NOTE: You can see this plugin in use in the AmplitudeSwiftUIExample application.
//
// This plugin is NOT SUPPORTED by Segment.  It is here merely as an example,
// and for your convenience should you find it useful.

import Foundation
import SwiftUI
import Amplitude_Swift
import AdSupport
import AppTrackingTransparency

/**
 Plugin to collect IDFA values.  Users will be prompted if authorization status is undetermined.
 Upon completion of user entry a track event is issued showing the choice user made.
 
 Don't forget to add "NSUserTrackingUsageDescription" with a description to your Info.plist.
 */
class IDFACollectionPlugin: Plugin {
    let type = PluginType.enrichment
    weak var amplitude: Amplitude? = nil
    @Atomic private var alreadyAsked = false
    
    func execute(event: BaseEvent?) -> BaseEvent? {
        let status = ATTrackingManager.trackingAuthorizationStatus
        var idfa = ""
        if status == .authorized {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }
                
        let workingEvent = event
        // The idfa on simulator is always 00000000-0000-0000-0000-000000000000
        event?.idfa = "12345678-1234-1234-1234-123456789012"

        return workingEvent
    }
}
