//
//  File.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public protocol EventOptions {
    var userId: String? { get set }
    var deviceId: String? { get set }
    var timestamp: Double? { get set }
    var eventId: Double? { get set }
    var sessionId: Double { get set }
    var insertId: String? { get set }
    var locationLat: Double? { get set }
    var locationLng: Double? { get set }
    var appVersion: String? { get set }
    var versionName: String? { get set }
    var platform: String? { get set }
    var osName: String? { get set }
    var osVersion: String? { get set }
    var deviceBrand: String? { get set }
    var deviceManufacturer: String? { get set }
    var deviceModel: String? { get set }
    var carrier: String? { get set }
    var country: String? { get set }
    var region: String? { get set }
    var city: String? { get set }
    var dma: String? { get set }
    var idfa: String? { get set }
    var idfv: String? { get set }
    var adid: String? { get set }
    var appSetId: String? { get set }
    var androidId: String? { get set }
    var language: String? { get set }
    var library: String? { get set }
    var ip: String? { get set }
    var plan: Plan? { get set }
    var ingestionMetadata: IngestionMetadata? { get set }
    var revenue: Double? { get set }
    var price: Double? { get set }
    var quantity: Int? { get set }
    var productId: String? { get set }
    var revenueType: String? { get set }
    var extra: [String: Any]? { get set }
    var callback: EventCallBack? { get set }
    var partnerId: String? { get set }
    var attempts: Int { get set }
}

public class BaseEvent: EventOptions {
    public var userId: String?
    public var deviceId: String?
    public var timestamp: Double?
    public var eventId: Double?
    public var sessionId: Double
    public var insertId: String?
    public var locationLat: Double?
    public var locationLng: Double?
    public var appVersion: String?
    public var versionName: String?
    public var platform: String?
    public var osName: String?
    public var osVersion: String?
    public var deviceBrand: String?
    public var deviceManufacturer: String?
    public var deviceModel: String?
    public var carrier: String?
    public var country: String?
    public var region: String?
    public var city: String?
    public var dma: String?
    public var idfa: String?
    public var idfv: String?
    public var adid: String?
    public var appSetId: String?
    public var androidId: String?
    public var language: String?
    public var library: String?
    public var ip: String?
    public var plan: Plan?
    public var ingestionMetadata: IngestionMetadata?
    public var revenue: Double?
    public var price: Double?
    public var quantity: Int?
    public var productId: String?
    public var revenueType: String?
    public var extra: [String: Any]?
    public var callback: EventCallBack?
    public var partnerId: String?
    public var attempts: Int
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
        appSetId: String? = nil,
        androidId: String? = nil,
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
        attempts: Int,
        eventType: String,
        eventProperties: [String: Any]? = nil,
        userProperties: [String: Any]? = nil,
        groups: [String: Any]? = nil,
        groupProperties: [String: Any]? = nil
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
        self.appSetId = appSetId
        self.androidId = androidId
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
        self.eventType = eventType
        self.eventProperties = eventProperties
        self.userProperties = userProperties
        self.groups = groups
        self.groupProperties = groupProperties
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
