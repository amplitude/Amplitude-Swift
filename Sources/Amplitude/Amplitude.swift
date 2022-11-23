import Foundation

public class Amplitude {
    var configuration: Configuration
    var instanceName: String
    internal var inForeground = false

    lazy var storage: Storage = {
        return self.configuration.storageProvider
    }()
    lazy var timeline: Timeline = {
        return Timeline()
    }()
    lazy var logger: any Logger = {
        return self.configuration.loggerProvider
    }()

    init(
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
    }

    convenience init(apiKey: String, configuration: Configuration) {
        configuration.apiKey = apiKey
        self.init(configuration: configuration)
    }

    @discardableResult
    func track(event: BaseEvent, options: EventOptions? = nil, callback: EventCallBack? = nil) -> Amplitude {
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
    func logEvent(event: BaseEvent) -> Amplitude {
        return track(event: event)
    }

    func identify(type: String) -> Amplitude {
        return self
    }

    func identify() -> Amplitude {
        return self
    }

    func groupIdentify() -> Amplitude {
        return self
    }

    func groupIdentify(
        groupType: String,
        groupName: String,
        groupProperties: [String: Any],
        options: [String: Any]
    ) -> Amplitude {
        return self
    }

    func logRevenue() -> Amplitude {
        return self
    }

    func revenue() -> Amplitude {
        return self
    }

    @discardableResult
    func add(plugin: Plugin) -> Amplitude {
        plugin.setup(amplitude: self)
        timeline.add(plugin: plugin)
        return self
    }

    func remove(plugin: Plugin) -> Amplitude {
        timeline.remove(plugin: plugin)
        return self
    }

    func flush() -> Amplitude {
        return self
    }

    func setUserId(userId: String) -> Amplitude {
        return self
    }

    func setDeviceId(deviceId: String) -> Amplitude {
        return self
    }

    func reset() -> Amplitude {
        return self
    }

    func onEnterForeground(timestamp: Double) {
        inForeground = true

        let dummySessionStartEvent = BaseEvent(eventType: "session_start")
        dummySessionStartEvent.timestamp = timestamp
        dummySessionStartEvent.sessionId = -1
        timeline.process(event: dummySessionStartEvent)
    }

    func onExitForeground() {
        inForeground = false
        // TODO: Need to make sure the flush won't block the main thread
        if configuration.flushEventsOnClose == true {
            _ = self.flush()
        }
    }

    public func apply(closure: (Plugin) -> Void) {
        timeline.apply(closure)
    }

    private func process(event: BaseEvent) {
        if configuration.optOut {
            logger.log(message: "Skip event based on opt out configuration")
            return
        }
        event.timestamp = event.timestamp ?? NSDate().timeIntervalSince1970
        timeline.process(event: event)
    }
}
