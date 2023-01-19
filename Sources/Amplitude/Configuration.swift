//
//  Configuration.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

@objc public class Configuration : NSObject {
    var apiKey: String
    var flushQueueSize: Int
    var flushIntervalMillis: Int
    var instanceName: String
    var optOut: Bool
    var storageProvider: any Storage
    var logLevel: LogLevelEnum
    var loggerProvider: Logger
    var minIdLength: Int?
    var partnerId: String?
    var callback: EventCallback?
    var flushMaxRetries: Int
    var useBatch: Bool
    var serverZone: ServerZone
    var serverUrl: String?
    var plan: Plan?
    var ingestionMetadata: IngestionMetadata?
    var trackingOptions: TrackingOptions?
    var enableCoppaControl: Bool?
    var flushEventsOnClose: Bool?
    var minTimeBetweenSessionsMillis: Int
    var trackingSessionEvents: Bool?

    public init(
        apiKey: String,
        flushQueueSize: Int = Constants.Configuration.FLUSH_QUEUE_SIZE,
        flushIntervalMillis: Int = Constants.Configuration.FLUSH_INTERVAL_MILLIS,
        instanceName: String = Constants.Configuration.DEFAULT_INSTANCE,
        optOut: Bool = false,
        storageProvider: (any Storage)? = nil,
        logLevel: LogLevelEnum = LogLevelEnum.WARN,
        loggerProvider: Logger = ConsoleLogger(),
        minIdLength: Int? = nil,
        partnerId: String? = nil,
        callback: EventCallback? = nil,
        flushMaxRetries: Int = Constants.Configuration.FLUSH_MAX_RETRIES,
        useBatch: Bool = false,
        serverZone: ServerZone = ServerZone.US,
        serverUrl: String = Constants.DEFAULT_API_HOST,
        plan: Plan? = nil,
        ingestionMetadata: IngestionMetadata? = nil,
        trackingOptions: TrackingOptions = TrackingOptions(),
        enableCoppaControl: Bool = false,
        flushEventsOnClose: Bool = true,
        minTimeBetweenSessionsMillis: Int = Constants.Configuration
            .MIN_TIME_BETWEEN_SESSIONS_MILLIS,
        trackingSessionEvents: Bool = true
    ) {
        self.apiKey = apiKey
        self.flushQueueSize = flushQueueSize
        self.flushIntervalMillis = flushIntervalMillis
        self.instanceName = instanceName
        self.optOut = optOut
        self.storageProvider = storageProvider ?? PersistentStorage(apiKey: apiKey)
        self.logLevel = logLevel
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
        self.trackingOptions = trackingOptions
        self.enableCoppaControl = enableCoppaControl
        self.flushEventsOnClose = flushEventsOnClose
        self.minTimeBetweenSessionsMillis = minTimeBetweenSessionsMillis
        self.trackingSessionEvents = trackingSessionEvents
        // Logging is OFF by default
        self.loggerProvider.logLevel = logLevel.rawValue
    }

    func isValid() -> Bool {
        return !apiKey.isEmpty && flushQueueSize > 0 && flushIntervalMillis > 0
            && minTimeBetweenSessionsMillis > 0
            && (minIdLength == nil || minIdLength! > 0)
    }
}
