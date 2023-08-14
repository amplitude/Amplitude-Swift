//
//  IDFACollectionPlugin.swift
//
//
//  Created by Alyssa.Yu on 12/7/22.
//

// This plugin example currently supports iOS 14+ only.
// NOTE: You can see this plugin in use in the AmplitudeSwiftUIExample application.
//
// This plugin is NOT SUPPORTED by Amplitude.  It is here merely as an example,
// and for your convenience should you find it useful.

import AdSupport
import Amplitude_Swift
import AppTrackingTransparency
import Foundation
import SwiftUI

/// Plugin to collect IDFA values.  Users will be prompted if authorization status is undetermined.
/// Upon completion of user entry a track event is issued showing the choice user made.
///
/// Don't forget to add "NSUserTrackingUsageDescription" with a description to your Info.plist.
class IDFACollectionPlugin: EnrichmentPlugin {
    func execute(event: BaseEvent?) -> BaseEvent? {
        let status = ATTrackingManager.trackingAuthorizationStatus
        var idfa = fallbackValue
        if status == .authorized {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        }

        let workingEvent = event
        // The idfa on simulator is always 00000000-0000-0000-0000-000000000000
        event?.idfa = idfa
        // If you want to use idfa for the device_id
        event?.deviceId = idfa
        return workingEvent
    }
}

extension IDFACollectionPlugin {
    var fallbackValue: String? {
        // fallback to the IDFV value.
        // this is also sent in event.context.device.id,
        // feel free to use a value that is more useful to you.
        return UIDevice.current.identifierForVendor?.uuidString
    }
}
