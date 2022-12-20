//
//  AmplitudeDestinationPlugin.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

public class AmplitudeDestinationPlugin: DestinationPlugin {
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

    public override func track(event: BaseEvent) -> BaseEvent? {
        enqueue(event: event)
        return event
    }

    public override func identify(event: IdentifyEvent) -> IdentifyEvent? {
        enqueue(event: event)
        return event
    }

    public override func groupIdentify(event: GroupIdentifyEvent) -> GroupIdentifyEvent? {
        enqueue(event: event)
        return event
    }

    public override func revenue(event: RevenueEvent) -> RevenueEvent? {
        enqueue(event: event)
        return event
    }

    public override func flush() {
        pipeline?.flush()
    }

    public override func setup(amplitude: Amplitude) {
        self.amplitude = amplitude
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline?.start()

        add(plugin: IdentityEventSender())
    }

    public override func execute(event: BaseEvent?) -> BaseEvent? {
        return event
    }
}
