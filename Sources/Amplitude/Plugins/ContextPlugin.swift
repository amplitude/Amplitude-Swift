//
//  ContextPlugin.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

class ContextPlugin: Plugin {
    var type: PluginType = PluginType.before
    public weak var amplitude: Amplitude?
    internal static var device = VendorSystem.current

    func execute(event: BaseEvent?) -> BaseEvent? {
        guard let workingEvent = event else { return event }

        let context = staticContext

        // merge context data
        mergeContext(event: workingEvent, context: context)

        return workingEvent
    }

    internal var staticContext = staticContextData()

    internal static func staticContextData() -> [String: Any] {
        var staticContext = [String: Any]()
        // library
        staticContext["library"] = "\(Constants.SDK_LIBRARY)/\(Constants.SDK_VERSION)"

        // app info
        let info = Bundle.main.infoDictionary
        let localizedInfo = Bundle.main.localizedInfoDictionary
        var app = [String: Any]()
        if let info = info {
            app.merge(info) { (_, new) in new }
        }

        if let localizedInfo = localizedInfo {
            app.merge(localizedInfo) { (_, new) in new }
        }

        if app.count != 0 {
            staticContext["version_name"] = app["CFBundleShortVersionString"] ?? ""
        }

        // platform/device info
        let device = self.device
        staticContext["device_manufacturer"] = device.manufacturer
        staticContext["device_model"] = device.model
        staticContext["vendorID"] = device.identifierForVendor
        staticContext["os_name"] = device.os_name
        staticContext["os_version"] = device.os_version
        staticContext["platform"] = device.platform
        if Locale.preferredLanguages.count > 0 {
            staticContext["language"] = Locale.preferredLanguages[0]
        }

        // TODO: need to add logic for multi carrier
        /* let networkInfo = NSClassFromString("CTTelephonyNetworkInfo")
        if networkInfo != nil {
            let subscriberCellularProvider = NSSelectorFromString("subscriberCellularProvider")
            let carrier = networkInfo?.method(for: subscriberCellularProvider) ?? "unknown"
            staticContext["carrier"] = carrier
        }
        */

        if Locale.preferredLanguages.count > 0 {
            staticContext["country"] = Locale.current.regionCode
        }

        return staticContext
    }

    internal func mergeContext(event: BaseEvent, context: [String: Any]) {
        if event.timestamp == nil {
            event.timestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        }
        if event.insertId == nil {
            event.insertId = NSUUID().uuidString
        }
        if event.library == nil {
            event.library = context["library"] as? String
        }
        if event.userId == nil {
            // TODO: get stored userId
            // event.userId = self.amplitude.store.userId
        }
        if event.deviceId == nil {
            // TODO: get stored deviceID
            // event.deviceId = self.amplitude.store.deviceId
        }
        if event.partnerId == nil {
            if let pId = self.amplitude?.configuration.partnerId {
                event.partnerId = pId
            }
        }
        if event.ip == nil {
            // get the ip in server side if there is no event level ip
            event.ip = "$remote"
        }
        let configuration = self.amplitude?.configuration
        let trackingOptions = configuration?.trackingOptions

        if configuration?.enableCoppaControl ?? false {
            trackingOptions?.mergeIn(other: TrackingOptions().forCoppaControl())
        }

        if trackingOptions?.shouldTrackVersionName() ?? false {
            event.versionName = context["version_name"] as? String
        }
        if trackingOptions?.shouldTrackOsName() ?? false {
            event.osName = context["os_name"] as? String
        }
        if trackingOptions?.shouldTrackOsVersion() ?? false {
            event.osVersion = context["os_version"] as? String
        }
        if trackingOptions?.shouldTrackDeviceManufacturer() ?? false {
            event.deviceManufacturer = context["device_manufacturer"] as? String
        }
        if trackingOptions?.shouldTrackDeviceModel() ?? false {
            event.deviceModel = context["device_model"] as? String
        }
        if trackingOptions?.shouldTrackCarrier() ?? false {
            event.carrier = context["carrier"] as? String
        }
        if trackingOptions?.shouldTrackIpAddress() ?? false {
            guard event.ip != nil else {
                event.ip = "$remote"
                return
            }
        }
        if trackingOptions?.shouldTrackCountry() ?? false && event.ip != "$remote" {
            event.country = context["country"] as? String
        }
        // TODO: get lat and lng from locationInfoBlock
        /*if (trackingOptions?.shouldTrackLatLng() ?? false) && (self.amplitude.locationInfoBlock != nil)  {
            let location = self.amplitude.locationInfoBlock();
            event.locationLat = location.lat
            event.locationLng = location.lng
        }*/
        if trackingOptions?.shouldTrackLanguage() ?? false {
            event.language = context["language"] as? String
        }
        if trackingOptions?.shouldTrackPlatform() ?? false {
            event.platform = context["platform"] as? String
        }
        if event.plan == nil {
            if let plan = self.amplitude?.configuration.plan {
                event.plan = plan
            }
        }
        if event.ingestionMetadata == nil {
            if let ingestionMetadata = self.amplitude?.configuration.ingestionMetadata {
                event.ingestionMetadata = ingestionMetadata
            }
        }
    }
}
