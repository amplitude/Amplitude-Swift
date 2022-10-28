public class Amplitude {
    var configuration: Configuration
    var instanceName: String
    init(configuration: Configuration, instanceName: String = "default") {
        self.configuration = configuration
        self.instanceName = instanceName
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
    
    func groupIdentify(groupType: String, groupName: String, groupProperties: [String: Any], options: [String: Any]) -> Amplitude {
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

func amplitude(apiKey: String, configs: Configuration) -> Amplitude {
    return Amplitude(configuration: Configuration(flushQueueSize: <#Int#>, flushIntervalMillis: <#Int#>, instanceName: <#String#>, optOut: <#Bool#>, storageProvider: <#Storage#>, logLvel: <#LogLevelEnum#>, loggerProvider: <#Logger#>, flushMaxRetries: <#Int#>, useBatch: <#Bool#>, serverZone: <#ServerZone#>), instanceName: "default")
}
