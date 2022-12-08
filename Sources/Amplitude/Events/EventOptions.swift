//
//  EventOptions.swift
//
//
//  Created by Marvin Liu on 11/3/22.
//

import Foundation

public class EventOptions {
    var userId: String?
    var deviceId: String?
    var timestamp: Int64?
    var eventId: Int64?
    var sessionId: Int64? = -1
    var insertId: String?
    var locationLat: Double?
    var locationLng: Double?
    var appVersion: String?
    var versionName: String?
    var platform: String?
    var osName: String?
    var osVersion: String?
    var deviceBrand: String?
    var deviceManufacturer: String?
    var deviceModel: String?
    var carrier: String?
    var country: String?
    var region: String?
    var city: String?
    var dma: String?
    var idfa: String?
    var idfv: String?
    var adid: String?
    var language: String?
    var library: String?
    var ip: String?
    var plan: Plan?
    var ingestionMetadata: IngestionMetadata?
    var revenue: Double?
    var price: Double?
    var quantity: Int?
    var productId: String?
    var revenueType: String?
    var extra: [String: Any]?
    var callback: EventCallback?
    var partnerId: String?
    internal var attempts: Int

    init(
        userId: String? = nil,
        deviceId: String? = nil,
        timestamp: Int64? = nil,
        eventId: Int64? = nil,
        sessionId: Int64? = -1,
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
        callback: EventCallback? = nil,
        partnerId: String? = nil,
        attempts: Int = 0
    ) {
        self.userId = userId
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.eventId = eventId
        self.sessionId = sessionId
        self.insertId = insertId
        self.locationLat = locationLat
        self.locationLng = locationLng
        self.appVersion = appVersion
        self.versionName = versionName
        self.platform = platform
        self.osName = osName
        self.osVersion = osVersion
        self.deviceBrand = deviceBrand
        self.deviceManufacturer = deviceManufacturer
        self.deviceModel = deviceModel
        self.carrier = carrier
        self.country = country
        self.region = region
        self.city = city
        self.dma = dma
        self.idfa = idfa
        self.idfv = idfv
        self.adid = adid
        self.language = language
        self.library = library
        self.ip = ip
        self.plan = plan
        self.ingestionMetadata = ingestionMetadata
        self.revenue = revenue
        self.price = price
        self.quantity = quantity
        self.productId = productId
        self.revenueType = revenueType
        self.extra = extra
        self.callback = callback
        self.partnerId = partnerId
        self.attempts = attempts
    }
}
