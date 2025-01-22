import Foundation

public class Amplitude {
    public private(set) var configuration: Configuration
    private var inForeground = false

    var sessionId: Int64 {
        sessions.sessionId
    }

    var state: State = State()
    var contextPlugin: ContextPlugin

    lazy var storage: any Storage = {
        return self.configuration.storageProvider
    }()

    lazy var identifyStorage: any Storage = {
        return self.configuration.identifyStorageProvider
    }()

    private let timelineLock = NSLock()
    private var _timeline: Timeline?
    var timeline: Timeline {
        timelineLock.synchronizedLazy(&_timeline) {
            Timeline()
        }
    }

    private var sessionsLock = NSLock()
    private var _sessions: Sessions?
    var sessions: Sessions {
        get {
            sessionsLock.synchronizedLazy(&_sessions) {
                Sessions(amplitude: self)
            }
        }
        set {
            sessionsLock.withLock {
                _sessions = newValue
            }
        }
    }

    public lazy var logger: (any Logger)? = {
        return self.configuration.loggerProvider
    }()

    let trackingQueue = DispatchQueue(label: "com.amplitude.analytics", target: .global(qos: .utility))

    public init(
        configuration: Configuration
    ) {
        self.configuration = configuration

        let contextPlugin = ContextPlugin()
        self.contextPlugin = contextPlugin

        migrateApiKeyStorages()
        migrateDefaultInstanceStorages()
        if configuration.migrateLegacyData && getStorageVersion() < .API_KEY_AND_INSTANCE_NAME && isSandboxEnabled() {
            RemnantDataMigration(self).execute()
        }
        migrateInstanceOnlyStorages()

        if let deviceId: String? = configuration.storageProvider.read(key: .DEVICE_ID) {
            state.deviceId = deviceId
        }
        if let userId: String? = configuration.storageProvider.read(key: .USER_ID) {
            state.userId = userId
        }

        if configuration.offline != NetworkConnectivityCheckerPlugin.Disabled,
           VendorSystem.current.networkConnectivityCheckingEnabled {
            _ = add(plugin: NetworkConnectivityCheckerPlugin())
        }
        // required plugin for specific platform, only has lifecyclePlugin now
        if let requiredPlugin = VendorSystem.current.requiredPlugin {
            _ = add(plugin: requiredPlugin)
        }
        _ = add(plugin: contextPlugin)
        _ = add(plugin: AnalyticsConnectorPlugin())
        _ = add(plugin: AnalyticsConnectorIdentityPlugin())
        _ = add(plugin: AmplitudeDestinationPlugin())

        // Monitor changes to optOut to send to Timeline
        configuration.optOutChanged = { [weak self] optOut in
            self?.timeline.onOptOutChanged(optOut)
        }

        trackingQueue.async { [self] in
            self.trimQueuedEvents()
        }
    }

    convenience init(apiKey: String, configuration: Configuration) {
        configuration.apiKey = apiKey
        self.init(configuration: configuration)
    }

    @discardableResult
    public func track(event: BaseEvent, options: EventOptions? = nil, callback: EventCallback? = nil) -> Amplitude {
        if options != nil {
            event.mergeEventOptions(eventOptions: options!)
        }
        if callback != nil {
            event.callback = callback
        }
        process(event: event)
        return self
    }

    @discardableResult
    public func track(eventType: String, eventProperties: [String: Any]? = nil, options: EventOptions? = nil) -> Amplitude {
        let event = BaseEvent(eventType: eventType)
        event.eventProperties = eventProperties
        if let eventOptions = options {
            event.mergeEventOptions(eventOptions: eventOptions)
        }
        process(event: event)
        return self
    }

    @discardableResult
    @available(*, deprecated, message: "use 'track' instead")
    public func logEvent(event: BaseEvent) -> Amplitude {
        return track(event: event)
    }

    @discardableResult
    public func identify(userProperties: [String: Any]?, options: EventOptions? = nil) -> Amplitude {
        return identify(identify: convertPropertiesToIdentify(userProperties: userProperties), options: options)
    }

    @discardableResult
    public func identify(identify: Identify, options: EventOptions? = nil) -> Amplitude {
        let event = IdentifyEvent()
        event.userProperties = identify.properties as [String: Any]
        if let eventOptions = options {
            event.mergeEventOptions(eventOptions: eventOptions)
            if eventOptions.userId != nil {
                setUserId(userId: eventOptions.userId)
            }
            if eventOptions.deviceId != nil {
                setDeviceId(deviceId: eventOptions.deviceId)
            }
        }
        process(event: event)
        return self
    }

    private func convertPropertiesToIdentify(userProperties: [String: Any]?) -> Identify {
        let identify = Identify()
        userProperties?.forEach { key, value in
            _ = identify.set(property: key, value: value)
        }
        return identify
    }

    @discardableResult
    public func groupIdentify(
        groupType: String,
        groupName: String,
        groupProperties: [String: Any]?,
        options: EventOptions? = nil
    ) -> Amplitude {
        return groupIdentify(
            groupType: groupType,
            groupName: groupName,
            identify: convertPropertiesToIdentify(userProperties: groupProperties),
            options: options
        )
    }

    @discardableResult
    public func groupIdentify(
        groupType: String,
        groupName: String,
        identify: Identify,
        options: EventOptions? = nil
    ) -> Amplitude {
        let event = GroupIdentifyEvent()
        var groups = [String: Any]()
        groups[groupType] = groupName
        event.groups = groups
        event.groupProperties = identify.properties
        if let eventOptions = options {
            event.mergeEventOptions(eventOptions: eventOptions)
        }
        process(event: event)
        return self
    }

    @discardableResult
    public func setGroup(
        groupType: String,
        groupName: String,
        options: EventOptions? = nil
    ) -> Amplitude {
        let identify = Identify().set(property: groupType, value: groupName)
        let event = IdentifyEvent()
        event.groups = [groupType: groupName]
        event.userProperties = identify.properties
        track(event: event, options: options)
        return self
    }

    @discardableResult
    public func setGroup(
        groupType: String,
        groupName: [String],
        options: EventOptions? = nil
    ) -> Amplitude {
        let identify = Identify().set(property: groupType, value: groupName)
        let event = IdentifyEvent()
        event.groups = [groupType: groupName]
        event.userProperties = identify.properties
        track(event: event, options: options)
        return self
    }

    @discardableResult
    @available(*, deprecated, message: "use 'revenue' instead")
    public func logRevenue() -> Amplitude {
        return self
    }

    @discardableResult
    public func revenue(
        revenue: Revenue,
        options: EventOptions? = nil
    ) -> Amplitude {
        guard revenue.isValid() else {
            logger?.warn(message: "Invalid revenue object, missing required fields")
            return self
        }

        let event = revenue.toRevenueEvent()
        if let eventOptions = options {
            event.mergeEventOptions(eventOptions: eventOptions)
        }
        _ = self.revenue(event: event)
        return self
    }

    @discardableResult
    public func revenue(event: RevenueEvent) -> Amplitude {
        process(event: event)
        return self
    }

    @discardableResult
    public func add(plugin: Plugin) -> Amplitude {
        plugin.setup(amplitude: self)
        if let _plugin = plugin as? ObservePlugin {
            state.add(plugin: _plugin)
        } else {
            timeline.add(plugin: plugin)
        }
        return self
    }

    @discardableResult
    public func remove(plugin: Plugin) -> Amplitude {
        if let _plugin = plugin as? ObservePlugin {
            state.remove(plugin: _plugin)
        } else {
            timeline.remove(plugin: plugin)
        }
        return self
    }

    @discardableResult
    public func flush() -> Amplitude {
        trackingQueue.async {
            self.timeline.apply { plugin in
                if let _plugin = plugin as? EventPlugin {
                    _plugin.flush()
                }
            }
        }
        return self
    }

    @discardableResult
    public func setUserId(userId: String?) -> Amplitude {
        try? storage.write(key: .USER_ID, value: userId)
        state.userId = userId
        timeline.onUserIdChanged(userId)
        return self
    }

    @discardableResult
    public func setDeviceId(deviceId: String?) -> Amplitude {
        try? storage.write(key: .DEVICE_ID, value: deviceId)
        state.deviceId = deviceId
        timeline.onDeviceIdChanged(deviceId)
        return self
    }

    public func getUserId() -> String? {
        return state.userId
    }

    public func getDeviceId() -> String? {
        return state.deviceId
    }

    public func getSessionId() -> Int64 {
        return sessions.sessionId
    }

    @discardableResult
    public func setSessionId(timestamp: Int64) -> Amplitude {
        trackingQueue.async { [self] in
            let sessionEvents: [BaseEvent]
            if timestamp >= 0 {
                sessionEvents = self.sessions.startNewSession(timestamp: timestamp)
            } else {
                sessionEvents = self.sessions.endCurrentSession()
            }
            self.sessions.assignEventId(events: sessionEvents).forEach { e in
                self.timeline.processEvent(event: e)
            }
        }
        return self
    }

    @discardableResult
    public func setSessionId(date: Date) -> Amplitude {
        let timestamp = Int64(date.timeIntervalSince1970 * 1000)
        setSessionId(timestamp: timestamp)
        return self
    }

    @discardableResult
    public func reset() -> Amplitude {
        setUserId(userId: nil)
        contextPlugin.initializeDeviceId(forceReset: true)
        return self
    }

    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }

    private func process(event: BaseEvent) {
        if configuration.optOut {
            logger?.log(message: "Skip event based on opt out configuration")
            return
        }
        let inForeground = inForeground
        trackingQueue.async { [self] in
            let events = self.sessions.processEvent(event: event, inForeground: inForeground)
            events.forEach { e in self.timeline.processEvent(event: e) }
        }
    }

    func onEnterForeground(timestamp: Int64) {
        inForeground = true
        let dummySessionStartEvent = BaseEvent(
            timestamp: timestamp,
            eventType: Constants.AMP_SESSION_START_EVENT
        )
        trackingQueue.async { [self] in
            // set inForeground to false to represent state before event was fired
            let events = self.sessions.processEvent(event: dummySessionStartEvent, inForeground: false)
            events.forEach { e in self.timeline.processEvent(event: e) }
        }
    }

    func onExitForeground(timestamp: Int64) {
        inForeground = false
        trackingQueue.async { [self] in
            self.sessions.lastEventTime = timestamp
        }
        if configuration.flushEventsOnClose == true {
            flush()
        }
    }

    private func getStorageVersion() -> PersistentStorageVersion {
        let storageVersionInt: Int? = configuration.storageProvider.read(key: .STORAGE_VERSION)
        let storageVersion: PersistentStorageVersion = (storageVersionInt == nil) ? PersistentStorageVersion.NO_VERSION : PersistentStorageVersion(rawValue: storageVersionInt!)!
        return storageVersion
    }

    private func migrateApiKeyStorages() {
        if getStorageVersion() >= PersistentStorageVersion.API_KEY {
            return
        }
        configuration.loggerProvider.debug(message: "Running migrateApiKeyStorages")
        if let persistentStorage = configuration.storageProvider as? PersistentStorage {
            let apiKeyStorage = PersistentStorage(storagePrefix: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-\(configuration.apiKey)", logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(source: apiKeyStorage, destination: persistentStorage, logger: logger).execute()
        }

        if let persistentIdentifyStorage = configuration.identifyStorageProvider as? PersistentStorage {
            let apiKeyIdentifyStorage = PersistentStorage(storagePrefix: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-identify-\(configuration.apiKey)", logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(source: apiKeyIdentifyStorage, destination: persistentIdentifyStorage, logger: logger).execute()
        }
    }

    private func migrateDefaultInstanceStorages() {
        if getStorageVersion() >= PersistentStorageVersion.INSTANCE_NAME ||
            configuration.instanceName != Constants.Configuration.DEFAULT_INSTANCE {
            return
        }
        configuration.loggerProvider.debug(message: "Running migrateDefaultInstanceStorages")
        let legacyDefaultInstanceName = "default_instance"
        if let persistentStorage = configuration.storageProvider as? PersistentStorage {
            let legacyStorage = PersistentStorage(storagePrefix: "storage-\(legacyDefaultInstanceName)", logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(source: legacyStorage, destination: persistentStorage, logger: logger).execute()
        }

        if let persistentIdentifyStorage = configuration.identifyStorageProvider as? PersistentStorage {
            let legacyIdentifyStorage = PersistentStorage(storagePrefix: "identify-\(legacyDefaultInstanceName)", logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(source: legacyIdentifyStorage, destination: persistentIdentifyStorage, logger: logger).execute()
        }
    }

    internal func migrateInstanceOnlyStorages() {
        if getStorageVersion() >= .API_KEY_AND_INSTANCE_NAME {
            configuration.loggerProvider.debug(message: "Skipping migrateInstanceOnlyStorages based on STORAGE_VERSION")
            return
        }
        configuration.loggerProvider.debug(message: "Running migrateInstanceOnlyStorages")

        let skipEventMigration = !isSandboxEnabled()
        // Only migrate sandboxed apps to avoid potential data pollution
        if skipEventMigration {
            configuration.loggerProvider.debug(message: "Skipping event migration in non-sandboxed app. Transfering UserDefaults only.")
        }

        let instanceName = configuration.getNormalizeInstanceName()
        if let persistentStorage = configuration.storageProvider as? PersistentStorage {
            let instanceOnlyEventPrefix = "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-storage-\(instanceName)"
            let instanceNameOnlyStorage = PersistentStorage(storagePrefix: instanceOnlyEventPrefix, logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(
                source: instanceNameOnlyStorage,
                destination: persistentStorage,
                logger: logger
            ).execute(skipEventFiles: skipEventMigration)
        }

        if let persistentIdentifyStorage = configuration.identifyStorageProvider as? PersistentStorage {
            let instanceOnlyIdentifyPrefix = "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-identify-\(instanceName)"
            let instanceNameOnlyIdentifyStorage = PersistentStorage(storagePrefix: instanceOnlyIdentifyPrefix, logger: self.logger, diagonostics: configuration.diagonostics)
            StoragePrefixMigration(
                source: instanceNameOnlyIdentifyStorage,
                destination: persistentIdentifyStorage,
                logger: logger
            ).execute(skipEventFiles: skipEventMigration)
        }

        do {
            // Store the current storage version
            try configuration.storageProvider.write(
                key: .STORAGE_VERSION,
                value: PersistentStorageVersion.API_KEY_AND_INSTANCE_NAME.rawValue as Int
            )
            configuration.loggerProvider.debug(message: "Updated STORAGE_VERSION to .API_KEY_AND_INSTANCE_NAME")
        } catch {
            configuration.loggerProvider.error(message: "Unable to set STORAGE_VERSION in storageProvider during migration")
        }
    }

    internal func isSandboxEnabled() -> Bool {
        return SandboxHelper().isSandboxEnabled()
    }

    func trimQueuedEvents() {
        logger?.debug(message: "Trimming queued events..")
        guard configuration.maxQueuedEventCount > 0,
              let eventBlocks: [URL] = storage.read(key: .EVENTS),
              !eventBlocks.isEmpty else {
            return
        }

        var eventCount = 0
        // Blocks are returned in sorted order, oldest -> newest. Reverse to count newest blocks first.
        // Only whole blocks are deleted, meaning up to maxQueuedEventCount + flushQueueSize - 1
        // events may be left on device.
        for eventBlock in eventBlocks.reversed() {
            if eventCount < configuration.maxQueuedEventCount {
                if let eventString = storage.getEventsString(eventBlock: eventBlock),
                   let eventArray =  BaseEvent.fromArrayString(jsonString: eventString) {
                    eventCount += eventArray.count
                }
            } else {
                logger?.debug(message: "Trimming \(eventBlock)")
                storage.remove(eventBlock: eventBlock)
            }
        }
        logger?.debug(message: "Completed trimming events, kept \(eventCount) most recent events")
    }
}
