//
//  BaseEvent.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import Foundation

public class BaseEvent: EventOptions {
    public var eventType: String
    public var eventProperties: [String: Any]?
    public var userProperties: [String: Any]?
    public var groups: [String: Any]?
    public var groupProperties: [String: Any]?

    init(
        userId: String? = nil,
        deviceId: String? = nil,
        timestamp: Double? = nil,
        eventId: Double? = nil,
        sessionId: Double? = -1,
        insertId: String? = nil,
        locationLat: Double? = nil,
        locationLng: Double? = nil,
        appVersion: String? = nil,
        versionName: String? = nil,
        platform: String? = nil,
        osName: String? = nil,
        osVersion: String? = nil,
        deviceBrand: String? = nil,
        deviceManufacturer: String? = nil,
        deviceModel: String? = nil,
        carrier: String? = nil,
        country: String? = nil,
        region: String? = nil,
        city: String? = nil,
        dma: String? = nil,
        idfa: String? = nil,
        idfv: String? = nil,
        adid: String? = nil,
        language: String? = nil,
        library: String? = nil,
        ip: String? = nil,
        plan: Plan? = nil,
        ingestionMetadata: IngestionMetadata? = nil,
        revenue: Double? = nil,
        price: Double? = nil,
        quantity: Int? = nil,
        productId: String? = nil,
        revenueType: String? = nil,
        extra: [String: Any]? = nil,
        callback: EventCallBack? = nil,
        partnerId: String? = nil,
        eventType: String,
        eventProperties: [String: Any]? = nil,
        userProperties: [String: Any]? = nil,
        groups: [String: Any]? = nil,
        groupProperties: [String: Any]? = nil
    ) {
        self.eventType = eventType
        self.eventProperties = eventProperties
        self.userProperties = userProperties
        self.groups = groups
        self.groupProperties = groupProperties
        super.init(
            userId: userId,
            deviceId: deviceId,
            timestamp: timestamp,
            eventId: eventId,
            sessionId: sessionId,
            insertId: insertId,
            locationLat: locationLat,
            locationLng: locationLng,
            appVersion: appVersion,
            versionName: versionName,
            platform: platform,
            osName: osName,
            osVersion: osVersion,
            deviceBrand: deviceBrand,
            deviceManufacturer: deviceManufacturer,
            deviceModel: deviceModel,
            carrier: carrier,
            country: country,
            region: region,
            city: city,
            dma: dma,
            idfa: idfa,
            idfv: idfv,
            adid: adid,
            language: language,
            library: library,
            ip: ip,
            plan: plan,
            ingestionMetadata: ingestionMetadata,
            revenue: revenue,
            price: price,
            quantity: quantity,
            productId: productId,
            revenueType: revenueType,
            extra: extra,
            callback: callback,
            partnerId: partnerId
        )
    }

    func mergeEventOptions(eventOptions: EventOptions) {
        userId = userId ?? eventOptions.userId
        deviceId = deviceId ?? eventOptions.deviceId
        timestamp = timestamp ?? eventOptions.timestamp
        eventId = eventId ?? eventOptions.eventId
        sessionId = (sessionId == nil || sessionId! < 0) ? eventOptions.sessionId : sessionId
        insertId = insertId ?? eventOptions.insertId
        locationLat = locationLat ?? eventOptions.locationLat
        locationLng = locationLng ?? eventOptions.locationLng
        appVersion = appVersion ?? eventOptions.appVersion
        versionName = versionName ?? eventOptions.versionName
        platform = platform ?? eventOptions.platform
        osName = osName ?? eventOptions.osName
        osVersion = osVersion ?? eventOptions.osVersion
        deviceBrand = deviceBrand ?? eventOptions.deviceBrand
        deviceManufacturer = deviceManufacturer ?? eventOptions.deviceManufacturer
        deviceModel = deviceModel ?? eventOptions.deviceModel
        carrier = carrier ?? eventOptions.carrier
        country = country ?? eventOptions.country
        region = region ?? eventOptions.region
        city = city ?? eventOptions.city
        dma = dma ?? eventOptions.dma
        idfa = idfa ?? eventOptions.idfa
        idfv = idfv ?? eventOptions.idfv
        adid = adid ?? eventOptions.adid
        language = language ?? eventOptions.language
        library = library ?? eventOptions.library
        ip = ip ?? eventOptions.ip
        plan = plan ?? eventOptions.plan
        ingestionMetadata = ingestionMetadata ?? eventOptions.ingestionMetadata
        revenue = revenue ?? eventOptions.revenue
        price = price ?? eventOptions.price
        quantity = quantity ?? eventOptions.quantity
        productId = productId ?? eventOptions.productId
        revenueType = revenueType ?? eventOptions.revenueType
        extra = extra ?? eventOptions.extra
        callback = callback ?? eventOptions.callback
        partnerId = partnerId ?? eventOptions.partnerId
    }

    func isValid() -> Bool {
        return userId != nil || deviceId != nil
    }
}
