//
//  File.swift
//  
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Configuration {
    var flushQueueSize: Int = 30
    var flushIntervalMillis: Int = 30 * 1000
    var instanceName: String = "default"
    var optOut: Bool = false
    var storageProvider: Storage = CoreDataStorage()
    var logLvel: LogLevelEnum = LogLevelEnum.WARN
    var loggerProvider: any Logger = ConsoleLogger()
    var minIdLength: Int?
    var partnerId: String?
    var callback: EventCallBack?
    var flushMaxRetries: Int = 5
    var useBatch: Bool = false
    var serverZone: ServerZone = ServerZone.US
    var serverUrl: String?
    var plan: Plan?
    var ingestionMetadata: IngestionMetadata?
    var trackingOptions: TrackingOptions?
    
    init(flushQueueSize: Int, flushIntervalMillis: Int, instanceName: String, optOut: Bool, storageProvider: Storage, logLvel: LogLevelEnum, loggerProvider: any Logger, minIdLength: Int? = nil, partnerId: String? = nil, callback: EventCallBack? = nil, flushMaxRetries: Int, useBatch: Bool, serverZone: ServerZone, serverUrl: String? = nil, plan: Plan? = nil, ingestionMetadata: IngestionMetadata? = nil) {
        self.flushQueueSize = flushQueueSize
        self.flushIntervalMillis = flushIntervalMillis
        self.instanceName = instanceName
        self.optOut = optOut
        self.storageProvider = storageProvider
        self.logLvel = logLvel
        self.loggerProvider = loggerProvider
        self.minIdLength = minIdLength
        self.partnerId = partnerId
        self.callback = callback
        self.flushMaxRetries = flushMaxRetries
        self.useBatch = useBatch
        self.serverZone = serverZone
        self.serverUrl = serverUrl
        self.plan = plan
        self.ingestionMetadata = ingestionMetadata
    }
}
