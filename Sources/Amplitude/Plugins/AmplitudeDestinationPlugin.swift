//
//  AmplitudeDestinationPlugin.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

public class AmplitudeDestinationPlugin: DestinationPlugin {
    public let timeline = Timeline()
    public var amplitude: Amplitude?
    public let type: PluginType = .destination
    private var pipeline: EventPipeline?

    internal func enqueue(event: BaseEvent?) {
        if let e = event {
            if e.isValid() {
                pipeline?.put(event: e)
            } else {
                logger?.error(message: "Event is invalid for missing information like userId and deviceId")
            }
        }
    }

    public func track(event: BaseEvent) -> BaseEvent? {
        enqueue(event: event)
        return event
    }

    public func identify(event: IdentifyEvent) -> IdentifyEvent? {
        enqueue(event: event)
        return event
    }

    public func groupIdentify(event: GroupIdentifyEvent) -> GroupIdentifyEvent? {
        enqueue(event: event)
        return event
    }

    public func revenue(event: RevenueEvent) -> RevenueEvent? {
        enqueue(event: event)
        return event
    }

    public func flush() {
        pipeline?.flush()
    }

    public func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline?.start()

        add(plugin: IdentityEventSender())
    }

    public func execute(event: BaseEvent?) -> BaseEvent? {
        return event
    }
}
