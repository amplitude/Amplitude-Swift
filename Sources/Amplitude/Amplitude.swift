public class Amplitude {
    var configuration: Configuration
    var instanceName: String
    init(
        configuration: Configuration,
        instanceName: String = Constants.Configuration.DEFAULT_INSTANCE
    ) {
        self.configuration = configuration
        self.instanceName = instanceName
    }

    convenience init(apiKey: String, configuration: Configuration) {
        configuration.apiKey = apiKey
        self.init(configuration: configuration)
    }

    func getInstance(instsanceName: String) -> Amplitude {
        return self
    }

    func track() -> Amplitude {
        return self
    }

    func logEvent() -> Amplitude {
        return self
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

    func add(plugin: Plugin) -> Amplitude {
        return self
    }

    func remove(plugin: Plugin) -> Amplitude {
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
}
