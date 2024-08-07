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
    @available(*, deprecated, renamed: "autocapture", message: "Please use `autocapture` instead.")
    public lazy var defaultTracking: DefaultTrackingOptions = {
        DefaultTrackingOptions(delegate: self)
    }() {
        didSet {
            defaultTracking.delegate = self
            autocapture = defaultTracking.autocaptureOptions
        }
    }
    public internal(set) var autocapture: AutocaptureOptions
    public var offline: Bool?
    internal let diagonostics: Diagnostics

    @available(*, deprecated, message: "Please use the `autocapture` parameter instead.")
    public convenience init(
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
        defaultTracking: DefaultTrackingOptions,
        identifyBatchIntervalMillis: Int = Constants.Configuration.IDENTIFY_BATCH_INTERVAL_MILLIS,
        migrateLegacyData: Bool = true,
        offline: Bool? = false
    ) {
        self.init(apiKey: apiKey,
            flushQueueSize: flushQueueSize,
            flushIntervalMillis: flushIntervalMillis,
            instanceName: instanceName,
            optOut: optOut,
            storageProvider: storageProvider,
            identifyStorageProvider: identifyStorageProvider,
            logLevel: logLevel,
            loggerProvider: loggerProvider,
            minIdLength: minIdLength,
            partnerId: partnerId,
            callback: callback,
            flushMaxRetries: flushMaxRetries,
            useBatch: useBatch,
            serverZone: serverZone,
            serverUrl: serverUrl,
            plan: plan,
            ingestionMetadata: ingestionMetadata,
            trackingOptions: trackingOptions,
            enableCoppaControl: enableCoppaControl,
            flushEventsOnClose: flushEventsOnClose,
            minTimeBetweenSessionsMillis: minTimeBetweenSessionsMillis,
            autocapture: defaultTracking.autocaptureOptions,
            identifyBatchIntervalMillis: identifyBatchIntervalMillis,
            migrateLegacyData: migrateLegacyData,
            offline: offline)
        self.defaultTracking = defaultTracking
    }

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
        autocapture: AutocaptureOptions = .sessions,
        identifyBatchIntervalMillis: Int = Constants.Configuration.IDENTIFY_BATCH_INTERVAL_MILLIS,
        migrateLegacyData: Bool = true,
        offline: Bool? = false
    ) {
        let normalizedInstanceName = Configuration.getNormalizeInstanceName(instanceName)

        self.apiKey = apiKey
        self.flushQueueSize = flushQueueSize
        self.flushIntervalMillis = flushIntervalMillis
        self.instanceName = normalizedInstanceName
        self.optOut = optOut
        self.diagonostics = Diagnostics()
        self.logLevel = logLevel
        self.loggerProvider = loggerProvider
        self.storageProvider = storageProvider
        ?? PersistentStorage(storagePrefix: PersistentStorage.getEventStoragePrefix(apiKey, normalizedInstanceName), logger: self.loggerProvider, diagonostics: self.diagonostics)
        self.identifyStorageProvider = identifyStorageProvider
        ?? PersistentStorage(storagePrefix: PersistentStorage.getIdentifyStoragePrefix(apiKey, normalizedInstanceName), logger: self.loggerProvider, diagonostics: self.diagonostics)
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
        self.autocapture = autocapture
        self.identifyBatchIntervalMillis = identifyBatchIntervalMillis
        self.migrateLegacyData = migrateLegacyData
        // Logging is OFF by default
        self.loggerProvider.logLevel = logLevel.rawValue
        self.offline = offline
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

extension Configuration: DefaultTrackingOptionsDelegate {
    @available(*, deprecated)
    func didChangeOptions(options: DefaultTrackingOptions) {
        autocapture = options.autocaptureOptions
    }
}
