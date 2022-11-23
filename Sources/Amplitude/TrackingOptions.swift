//
//  TrackingOptions.swift
//
//
//  Created by Marvin Liu on 10/28/22.
//

import Foundation

public class TrackingOptions {

    private let COPPA_CONTROL_PROPERTIES = [
        Constants.AMP_TRACKING_OPTION_IDFA,
        Constants.AMP_TRACKING_OPTION_IDFV,
        Constants.AMP_TRACKING_OPTION_CITY,
        Constants.AMP_TRACKING_OPTION_IP_ADDRESS,
        Constants.AMP_TRACKING_OPTION_LAT_LNG,
    ]

    var disabledFields: Set<String> = []

    func shouldTrackVersionName() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_VERSION_NAME)
    }

    func disableTrackVersionName() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_VERSION_NAME)
        return self
    }

    func shouldTrackOsName() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_OS_NAME)
    }

    func disableTrackOsName() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_OS_NAME)
        return self
    }

    func shouldTrackOsVersion() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_OS_VERSION)
    }

    func disableTrackOsVersion() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_OS_VERSION)
        return self
    }

    func shouldTrackDeviceManufacturer() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DEVICE_MANUFACTURER)
    }

    func disableTrackDeviceManufacturer() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DEVICE_MANUFACTURER)
        return self
    }

    func shouldTrackDeviceModel() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DEVICE_MODEL)
    }

    func disableTrackDeviceModel() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DEVICE_MODEL)
        return self
    }

    func shouldTrackCarrier() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_CARRIER)
    }

    func disableCarrier() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_CARRIER)
        return self
    }

    func shouldTrackIpAddress() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IP_ADDRESS)
    }

    func disableTrackIpAddress() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IP_ADDRESS)
        return self
    }

    func shouldTrackCountry() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_COUNTRY)
    }

    func disableTrackCountry() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_COUNTRY)
        return self
    }

    func shouldTrackCity() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_CITY)
    }

    func disableTrackCity() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_CITY)
        return self
    }

    func shouldTrackDMA() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_DMA)
    }

    func disableTrackDMA() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_DMA)
        return self
    }

    func shouldTrackIDFA() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IDFA)
    }

    func disableTrackIDFA() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IDFA)
        return self
    }

    func shouldTrackIDFV() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_IDFV)
    }

    func disableTrackIDFV() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_IDFV)
        return self
    }

    func shouldTrackLanguage() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_LANGUAGE)
    }

    func disableTrackLanguage() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_LANGUAGE)
        return self
    }

    func shouldTrackRegion() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_REGION)
    }

    func disableTrackRegion() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_REGION)
        return self
    }

    func shouldTrackPlatform() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_PLATFORM)
    }

    func disableTrackPlatform() -> TrackingOptions {
        disabledFields.insert(Constants.AMP_TRACKING_OPTION_PLATFORM)
        return self
    }

    func shouldTrackLatLng() -> Bool {
        return shouldTrackField(field: Constants.AMP_TRACKING_OPTION_LAT_LNG)
    }

    func disableTrackLatLng() -> TrackingOptions {
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
