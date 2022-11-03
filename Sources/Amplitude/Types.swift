//
//  File.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class EventOptions {
    var userId: String?
    var deviceId: String?
    var timestamp: Double?
    var eventId: Double?
    var sessionId: Double
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
    var callback: EventCallBack?
    var partnerId: String?
    private var attempts: Int

    init(
        userId: String? = nil,
        deviceId: String? = nil,
        timestamp: Double? = nil,
        eventId: Double? = nil,
        sessionId: Double = -1,
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
        sessionId: Double,
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
}

public class IdentifyEvent: BaseEvent {
    override public var eventType: String {
        get {
            return "$identify"
        }
        set {
        }
    }
}

public class RevenueEvent: BaseEvent {
    override public var eventType: String {
        get {
            return "revenue_amount"
        }
        set {
        }
    }
}

public class GroupIdentifyEvent: BaseEvent {
    override public var eventType: String {
        get {
            return "$groupidentify"
        }
        set {
        }
    }
}

public struct Plan {
    var branch: String?
    var source: String?
    var version: String?
    var versionId: String?
}

public struct IngestionMetadata {
    var sourceName: String?
    var sourceVersion: String?
}

public protocol EventCallBack {

}

public protocol Storage {
    func set(key: String, value: String) async
    func get(key: String) async -> String?
    func saveEvent(event: BaseEvent) async
    func getEvents() async -> [Any]?
    func reset() async
}

public protocol Logger {
    associatedtype LogLevel: RawRepresentable
    var logLevel: Int? { get set }
    func error(message: String)
    func warn(message: String)
    func log(message: String)
    func debug(message: String)
}

public enum PluginType: String {
    case before = "Before"
    case enrichment = "Enrichment"
    case destination = "Destination"
    case utility = "Utility"
    case observe = "Observe"
}

public protocol Plugin {
    var type: PluginType { get }
    var amplitude: Amplitude? { get set }
    func setup(amplitude: Amplitude)
    func execute(event: BaseEvent) -> BaseEvent?
}
