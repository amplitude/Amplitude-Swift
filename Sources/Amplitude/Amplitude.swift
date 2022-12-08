import Foundation

public class Amplitude {
    var configuration: Configuration
    var instanceName: String
    var _inForeground = false
    internal var _sessionId: Int64 = -1

    lazy var storage: any Storage = {
        return self.configuration.storageProvider
    }()

    lazy var timeline: Timeline = {
        let timeline = Timeline()
        timeline.amplitude = self
        return timeline
    }()

    lazy var logger: (any Logger)? = {
        return self.configuration.loggerProvider
    }()

    public init(
        configuration: Configuration,
        instanceName: String = Constants.Configuration.DEFAULT_INSTANCE
    ) {
        self.configuration = configuration
        self.instanceName = instanceName
        // required plugin for specific platform, only has lifecyclePlugin now
        if let requiredPlugin = VendorSystem.current.requiredPlugin {
            _ = add(plugin: requiredPlugin)
        }
        _ = add(plugin: ContextPlugin())
        _ = add(plugin: AmplitudeDestinationPlugin())
        timeline.start()
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

    @available(*, deprecated, message: "use 'track' instead")
    public func logEvent(event: BaseEvent) -> Amplitude {
        return track(event: event)
    }

    public func identify(type: String) -> Amplitude {
        return self
    }

    public func identify() -> Amplitude {
        return self
    }

    public func groupIdentify() -> Amplitude {
        return self
    }

    public func groupIdentify(
        groupType: String,
        groupName: String,
        groupProperties: [String: Any],
        options: [String: Any]
    ) -> Amplitude {
        return self
    }

    public func logRevenue() -> Amplitude {
        return self
    }

    public func revenue() -> Amplitude {
        return self
    }

    @discardableResult
    public func add(plugin: Plugin) -> Amplitude {
        plugin.setup(amplitude: self)
        timeline.add(plugin: plugin)
        return self
    }

    public func remove(plugin: Plugin) -> Amplitude {
        timeline.remove(plugin: plugin)
        return self
    }

    public func flush() -> Amplitude {
        return self
    }

    public func setUserId(userId: String) -> Amplitude {
        return self
    }

    public func setDeviceId(deviceId: String) -> Amplitude {
        return self
    }

    public func setSessionId(sessionId: Int64) -> Amplitude {
        _sessionId = sessionId
        _ = try? self.storage.write(key: .PREVIOUS_SESSION_ID, value: sessionId)
        return self
    }

    func reset() -> Amplitude {
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
        event.timestamp = event.timestamp ?? Int64(NSDate().timeIntervalSince1970 * 1000)
        timeline.process(event: event)
    }

    func onEnterForeground(timestamp: Int64) {
        _inForeground = true
        let dummySessionStartEvent = BaseEvent(
            timestamp: timestamp,
            sessionId: -1,
            eventType: Constants.AMP_SESSION_START_EVENT
        )
        timeline.process(event: dummySessionStartEvent)
    }

    func onExitForeground() {
        _inForeground = false
        if configuration.flushEventsOnClose == true {
            _ = self.flush()
        }
    }

}
