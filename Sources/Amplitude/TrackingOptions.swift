//
//  TrackingOptions.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

public class TrackingOptions {

    public init() {}

    private let COPPA_CONTROL_PROPERTIES = [
        Constants.AMP_TRACKING_OPTION_IDFA,
        Constants.AMP_TRACKING_OPTION_IDFV,
        Constants.AMP_TRACKING_OPTION_CITY,
        Constants.AMP_TRACKING_OPTION_IP_ADDRESS,
        Constants.AMP_TRACKING_OPTION_LAT_LNG,
    ]

    var disabledFields: Set<String> = []

    public func shouldTrackVersionName() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_VERSION_NAME)
    }

    public func disableTrackVersionName() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_VERSION_NAME)
        return self
    }

    public func shouldTrackOsName() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_OS_NAME)
    }

    public func disableTrackOsName() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_OS_NAME)
        return self
    }

    public func shouldTrackOsVersion() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_OS_VERSION)
    }

    public func disableTrackOsVersion() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_OS_VERSION)
        return self
    }

    public func shouldTrackDeviceManufacturer() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DEVICE_MANUFACTURER)
    }

    public func disableTrackDeviceManufacturer() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DEVICE_MANUFACTURER)
        return self
    }

    public func shouldTrackDeviceModel() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DEVICE_MODEL)
    }

    public func disableTrackDeviceModel() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DEVICE_MODEL)
        return self
    }

    public func shouldTrackCarrier() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_CARRIER)
    }

    public func disableCarrier() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_CARRIER)
        return self
    }

    public func shouldTrackIpAddress() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IP_ADDRESS)
    }

    public func disableTrackIpAddress() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IP_ADDRESS)
        return self
    }

    public func shouldTrackCountry() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_COUNTRY)
    }

    public func disableTrackCountry() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_COUNTRY)
        return self
    }

    public func shouldTrackCity() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_CITY)
    }

    public func disableTrackCity() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_CITY)
        return self
    }

    public func shouldTrackDMA() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DMA)
    }

    public func disableTrackDMA() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DMA)
        return self
    }

    public func shouldTrackIDFA() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IDFA)
    }

    public func disableTrackIDFA() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IDFA)
        return self
    }

    public func shouldTrackIDFV() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IDFV)
    }

    public func disableTrackIDFV() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IDFV)
        return self
    }

    public func shouldTrackLanguage() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_LANGUAGE)
    }

    public func disableTrackLanguage() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_LANGUAGE)
        return self
    }

    public func shouldTrackRegion() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_REGION)
    }

    public func disableTrackRegion() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_REGION)
        return self
    }

    public func shouldTrackPlatform() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_PLATFORM)
    }

    public func disableTrackPlatform() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_PLATFORM)
        return self
    }

    public func shouldTrackLatLng() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_LAT_LNG)
    }

    public func disableTrackLatLng() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_LAT_LNG)
        return self
    }

    func forCoppaControl() -> TrackingOptions {
        let trackingOptions = TrackingOptions()
        for property in COPPA_CONTROL_PROPERTIES {
            trackingOptions.disableTrackingField(field: property)
        }

        return trackingOptions
    }

    @discardableResult
    func mergeIn(other: TrackingOptions) -> TrackingOptions {
        for key in other.disabledFields {
            disableTrackingField(field: key)
        }
        return self
    }

    private func shouldTrackField(field: String) -> Bool {
        return !disabledFields.contains(field)
    }

    private func disableTrackingField(field: String) {
        disabledFields.insert(field)
    }
}
