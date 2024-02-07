//
//  Configuration.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

import Foundation

public class Configuration {
    public internal(set) var apiKey: String
    public var flushQueueSize: Int
    public var flushIntervalMillis: Int
    public internal(set) var instanceName: String
    public var optOut: Bool
    public let storageProvider: any Storage
    public let identifyStorageProvider: any Storage
    public var logLevel: LogLevelEnum
    public var loggerProvider: any Logger
    public var minIdLength: Int?
    public var partnerId: String?
    public var callback: EventCallback?
    public var flushMaxRetries: Int
    public var useBatch: Bool
    public var serverZone: ServerZone
    public var serverUrl: String?
    public var plan: Plan?
    public var ingestionMetadata: IngestionMetadata?
    public var trackingOptions: TrackingOptions
    public var enableCoppaControl: Bool
    public var flushEventsOnClose: Bool
    public var minTimeBetweenSessionsMillis: Int
    public var identifyBatchIntervalMillis: Int
    public internal(set) var migrateLegacyData: Bool
    public var defaultTracking: DefaultTrackingOptions

    public init(
        apiKey: String,
        flushQueueSize: Int = Constants.Configuration.FLUSH_QUEUE_SIZE,
        flushIntervalMillis: Int = Constants.Configuration.FLUSH_INTERVAL_MILLIS,
        instanceName: String = "",
        optOut: Bool = false,
        storageProvider: (any Storage)? = nil,
        identifyStorageProvider: (any Storage)? = nil,
        logLevel: LogLevelEnum = LogLevelEnum.WARN,
        loggerProvider: any Logger = ConsoleLogger(),
        minIdLength: Int? = nil,
        partnerId: String? = nil,
        callback: EventCallback? = nil,
        flushMaxRetries: Int = Constants.Configuration.FLUSH_MAX_RETRIES,
        useBatch: Bool = false,
        serverZone: ServerZone = ServerZone.US,
        serverUrl: String? = nil,
        plan: Plan? = nil,
        ingestionMetadata: IngestionMetadata? = nil,
        trackingOptions: TrackingOptions = TrackingOptions(),
        enableCoppaControl: Bool = false,
        flushEventsOnClose: Bool = true,
        minTimeBetweenSessionsMillis: Int = Constants.Configuration.MIN_TIME_BETWEEN_SESSIONS_MILLIS,
        // `trackingSessionEvents` has been replaced by `defaultTracking.sessions`
        defaultTracking: DefaultTrackingOptions = DefaultTrackingOptions(),
        identifyBatchIntervalMillis: Int = Constants.Configuration.IDENTIFY_BATCH_INTERVAL_MILLIS,
        migrateLegacyData: Bool = true
    ) {
        let normalizedInstanceName = Configuration.getNormalizeInstanceName(instanceName)

        self.apiKey = apiKey
        self.flushQueueSize = flushQueueSize
        self.flushIntervalMillis = flushIntervalMillis
        self.instanceName = normalizedInstanceName
        self.optOut = optOut
        self.storageProvider = storageProvider
            ?? PersistentStorage(storagePrefix: PersistentStorage.getEventStoragePrefix(apiKey, normalizedInstanceName))
        self.identifyStorageProvider = identifyStorageProvider
            ?? PersistentStorage(storagePrefix: PersistentStorage.getIdentifyStoragePrefix(apiKey, normalizedInstanceName))
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
        self.defaultTracking = defaultTracking
        self.identifyBatchIntervalMillis = identifyBatchIntervalMillis
        self.migrateLegacyData = migrateLegacyData
        // Logging is OFF by default
        self.loggerProvider.logLevel = logLevel.rawValue
    }

    func isValid() -> Bool {
        return !apiKey.isEmpty && flushQueueSize > 0 && flushIntervalMillis > 0
            && minTimeBetweenSessionsMillis > 0
            && (minIdLength == nil || minIdLength! > 0)
    }

    private class func getNormalizeInstanceName(_ instanceName: String) -> String {
        return instanceName == "" ? Constants.Configuration.DEFAULT_INSTANCE : instanceName
    }
    
    internal func getNormalizeInstanceName() -> String {
        return Configuration.getNormalizeInstanceName(self.instanceName)
    }
}
