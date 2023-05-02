//
//  DestinationPlugin.swift
//
//
//  Created by Hao Yu on 11/15/22.
//

open class DestinationPlugin: EventPlugin {
    public let type: PluginType = .destination
    public var amplitude: Amplitude?

    public init() {
    }

    open func track(event: BaseEvent) -> BaseEvent? {
        return event
    }

    open func identify(event: IdentifyEvent) -> IdentifyEvent? {
        return event
    }

    open func groupIdentify(event: GroupIdentifyEvent) -> GroupIdentifyEvent? {
        return event
    }

    open func revenue(event: RevenueEvent) -> RevenueEvent? {
        return event
    }

    open func flush() {
    }

    open func execute(event: BaseEvent?) -> BaseEvent? {
        return event
    }

    open func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
    }
}

extension DestinationPlugin {
    var enabled: Bool {
        return true
    }

    var logger: (any Logger)? {
        return self.amplitude?.logger
    }

    func process(event: BaseEvent?) -> BaseEvent? {
        // Skip this destination if it is disabled via settings
        if !enabled {
            return nil
        }
        var destinationResult: BaseEvent?
        switch event {
        case let e as IdentifyEvent:
            destinationResult = identify(event: e)
        case let e as GroupIdentifyEvent:
            destinationResult = track(event: e)
        case let e as RevenueEvent:
            destinationResult = revenue(event: e)
        case let e?:
            destinationResult = track(event: e)
        default:
            break
        }
        return destinationResult
    }
}
