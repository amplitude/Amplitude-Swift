//
//  BaseEvent.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import Foundation

public class BaseEvent: EventOptions, Codable {
    public var eventType: String
    public var eventProperties: [String: Any]?
    public var userProperties: [String: Any]?
    public var groups: [String: Any]?
    public var groupProperties: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case eventProperties = "event_properties"
        case userProperties = "user_properties"
        case groups
        case groupProperties = "group_properties"
        case userId = "user_id"
        case deviceId = "device_id"
        case timestamp = "time"
        case eventId = "event_id"
        case sessionId = "session_id"
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case appVersion = "app_version"
        case versionName = "version_name"
        case platform
        case osName = "os_name"
        case osVersion = "os_version"
        case deviceBrand = "device_brand"
        case deviceManufacturer = "device_manufacturer"
        case deviceModel = "device_model"
        case carrier
        case country
        case region
        case city
        case dma
        case idfa
        case idfv
        case adid
        case language
        case library
        case ip
        case plan
        case ingestionMetadata = "ingestion_metadata"
        case revenue
        case price
        case quantity
        case productId = "product_id"
        case revenueType = "revenue_type"
        case partnerId = "partner_id"
    }

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

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        eventType = try values.decode(String.self, forKey: .eventType)
        eventProperties = try values.decode([String: Any].self, forKey: .eventProperties)
        userProperties = try values.decode([String: Any].self, forKey: .userProperties)
        groups = try values.decode([String: Any].self, forKey: .groups)
        groupProperties = try values.decode([String: Any].self, forKey: .groupProperties)
        super.init()
        userId = try values.decode(String.self, forKey: .userId)
        deviceId = try values.decode(String.self, forKey: .deviceId)
        timestamp = try values.decode(Double.self, forKey: .timestamp)
        eventId = try values.decode(Double.self, forKey: .eventId)
        sessionId = try values.decode(Double.self, forKey: .sessionId)
        locationLat = try values.decode(Double.self, forKey: .locationLat)
        locationLng = try values.decode(Double.self, forKey: .locationLng)
        appVersion = try values.decode(String.self, forKey: .appVersion)
        versionName = try values.decode(String.self, forKey: .versionName)
        platform = try values.decode(String.self, forKey: .platform)
        osName = try values.decode(String.self, forKey: .osName)
        osVersion = try values.decode(String.self, forKey: .osVersion)
        deviceBrand = try values.decode(String.self, forKey: .deviceBrand)
        deviceManufacturer = try values.decode(String.self, forKey: .deviceManufacturer)
        deviceModel = try values.decode(String.self, forKey: .deviceModel)
        carrier = try values.decode(String.self, forKey: .carrier)
        country = try values.decode(String.self, forKey: .country)
        region = try values.decode(String.self, forKey: .region)
        city = try values.decode(String.self, forKey: .city)
        dma = try values.decode(String.self, forKey: .dma)
        idfa = try values.decode(String.self, forKey: .idfa)
        idfv = try values.decode(String.self, forKey: .idfv)
        adid = try values.decode(String.self, forKey: .adid)
        language = try values.decode(String.self, forKey: .language)
        library = try values.decode(String.self, forKey: .library)
        ip = try values.decode(String.self, forKey: .ip)
        plan = try values.decode(Plan.self, forKey: .plan)
        ingestionMetadata = try values.decode(IngestionMetadata.self, forKey: .ingestionMetadata)
        revenue = try values.decode(Double.self, forKey: .revenue)
        price = try values.decode(Double.self, forKey: .price)
        quantity = try values.decode(Int.self, forKey: .quantity)
        productId = try values.decode(String.self, forKey: .productId)
        revenueType = try values.decode(String.self, forKey: .revenueType)
        partnerId = try values.decode(String.self, forKey: .partnerId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(eventProperties, forKey: .eventProperties)
        try container.encodeIfPresent(userProperties, forKey: .userProperties)
        try container.encodeIfPresent(groups, forKey: .groups)
        try container.encodeIfPresent(groupProperties, forKey: .groupProperties)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(locationLat, forKey: .locationLat)
        try container.encode(locationLng, forKey: .locationLng)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(versionName, forKey: .versionName)
        try container.encode(platform, forKey: .platform)
        try container.encode(osName, forKey: .osName)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encode(deviceBrand, forKey: .deviceBrand)
        try container.encode(deviceManufacturer, forKey: .deviceManufacturer)
        try container.encode(deviceModel, forKey: .deviceModel)
        try container.encode(carrier, forKey: .carrier)
        try container.encode(country, forKey: .country)
        try container.encode(region, forKey: .region)
        try container.encode(city, forKey: .city)
        try container.encode(dma, forKey: .dma)
        try container.encode(idfa, forKey: .idfa)
        try container.encode(idfv, forKey: .idfv)
        try container.encode(adid, forKey: .adid)
        try container.encode(language, forKey: .language)
        try container.encode(library, forKey: .library)
        try container.encode(ip, forKey: .ip)
        try container.encodeIfPresent(plan, forKey: .plan)
        try container.encodeIfPresent(ingestionMetadata, forKey: .ingestionMetadata)
        try container.encode(revenue, forKey: .revenue)
        try container.encode(price, forKey: .price)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(productId, forKey: .productId)
        try container.encode(revenueType, forKey: .revenueType)
        try container.encode(partnerId, forKey: .partnerId)
    }
}

extension BaseEvent {
    func toString() -> String {
        var returnString = ""
        do {
            let encoder = JSONEncoder()
            let json = try encoder.encode(self)
            if let printed = String(data: json, encoding: .utf8) {
                returnString = printed
            }
        } catch {
            returnString = error.localizedDescription
        }
        return returnString
    }
}
