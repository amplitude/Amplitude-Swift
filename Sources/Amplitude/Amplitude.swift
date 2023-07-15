import Foundation

public class Amplitude {
    public private(set) var configuration: Configuration
    private var inForeground = false

    var sessionId: Int64 {
        sessions.sessionId
    }

    var state: State = State()
    var contextPlugin: ContextPlugin

    /**
     Sets a block to be called when location (latitude, longitude) information can be passed into an event.

     let locationInfo = LocationInfo(lat: 37.7, lng: 122.4)
     Amplitude.testInstance.locationInfoBlock = {
         return locationInfo
     }
     */
    public var locationInfoBlock: LocationInfoBlock?

    lazy var storage: any Storage = {
        return self.configuration.storageProvider
    }()

    lazy var timeline: Timeline = {
        return Timeline()
    }()

    lazy var sessions: Sessions = {
        return Sessions(amplitude: self)
    }()

    public lazy var logger: (any Logger)? = {
        return self.configuration.loggerProvider
    }()

    public init(
        configuration: Configuration
    ) {
        self.configuration = configuration

        let contextPlugin = ContextPlugin()
        self.contextPlugin = contextPlugin

        migrateApiKeyStorages()

        // required plugin for specific platform, only has lifecyclePlugin now
        if let requiredPlugin = VendorSystem.current.requiredPlugin {
            _ = add(plugin: requiredPlugin)
        }
        _ = add(plugin: contextPlugin)
        _ = add(plugin: AmplitudeDestinationPlugin())
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
    public func track(eventType: String, eventProperties: [String: Any]? = nil, options: EventOptions? = nil)
        -> Amplitude
    {
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
                _ = setUserId(userId: eventOptions.userId)
            }
            if eventOptions.deviceId != nil {
                _ = setDeviceId(deviceId: eventOptions.deviceId)
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
        let event = IdentifyEvent()
        event.groups = [groupType: groupName]
        track(event: event, options: options)
        return self
    }

    @discardableResult
    public func setGroup(
        groupType: String,
        groupName: [String],
        options: EventOptions? = nil
    ) -> Amplitude {
        let event = IdentifyEvent()
        event.groups = [groupType: groupName]
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
        timeline.add(plugin: plugin)
        return self
    }

    @discardableResult
    public func remove(plugin: Plugin) -> Amplitude {
        timeline.remove(plugin: plugin)
        return self
    }

    @discardableResult
    public func flush() -> Amplitude {
        timeline.apply { plugin in
            if let _plugin = plugin as? EventPlugin {
                _plugin.flush()
            }
        }
        return self
    }

    @discardableResult
    public func setUserId(userId: String?) -> Amplitude {
        try? storage.write(key: .USER_ID, value: userId)
        state.userId = userId
        return self
    }

    @discardableResult
    public func setDeviceId(deviceId: String?) -> Amplitude {
        try? storage.write(key: .DEVICE_ID, value: deviceId)
        state.deviceId = deviceId
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
    public func reset() -> Amplitude {
        _ = setUserId(userId: nil)
        _ = setDeviceId(deviceId: nil)
        contextPlugin.initializeDeviceId()
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
        let events = sessions.processEvent(event: event, inForeground: inForeground)
        events.forEach { e in timeline.processEvent(event: e) }
    }

    func onEnterForeground(timestamp: Int64) {
        inForeground = true
        let dummySessionStartEvent = BaseEvent(
            timestamp: timestamp,
            eventType: Constants.AMP_SESSION_START_EVENT
        )
        let events = sessions.processEvent(event: dummySessionStartEvent, inForeground: false)
        events.forEach { e in timeline.processEvent(event: e) }
    }

    func onExitForeground(timestamp: Int64) {
        inForeground = false
        sessions.lastEventTime = timestamp
        if configuration.flushEventsOnClose == true {
            _ = self.flush()
        }
    }

    private func migrateApiKeyStorages() {
        if let persistentStorage = configuration.storageProvider as? PersistentStorage {
            let apiKeyStorage = PersistentStorage(storagePrefix: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-\(configuration.apiKey)")
            StoragePrefixMigration(source: apiKeyStorage, destination: persistentStorage).execute()
        }

        if let persistentIdentifyStorage = configuration.identifyStorageProvider as? PersistentStorage {
            let apiKeyIdentifyStorage = PersistentStorage(storagePrefix: "\(PersistentStorage.DEFAULT_STORAGE_PREFIX)-identify-\(configuration.apiKey)")
            StoragePrefixMigration(source: apiKeyIdentifyStorage, destination: persistentIdentifyStorage).execute()
        }
    }
}
