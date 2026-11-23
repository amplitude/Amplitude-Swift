//
//  AmplitudeDestinationPlugin.swift
//
//
//  Created by Marvin Liu on 10/27/22.
//

public class AmplitudeDestinationPlugin: DestinationPlugin {
    private(set) var pipeline: EventPipeline?
    private var identifyInterceptor: IdentifyInterceptor?

    internal func enqueue(event: BaseEvent?) {
        if let event {
            if event.isValid() {
                let e = identifyInterceptor?.intercept(event: event)
                if let e {
                    pipeline?.put(event: e)
                }
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
        identifyInterceptor?.transferInterceptedIdentifyEvent()
        pipeline?.flush()
    }

    public override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        let pipeline = EventPipeline(amplitude: amplitude)
        self.pipeline = pipeline
        identifyInterceptor = IdentifyInterceptor(
            pipeline: pipeline,
            queue: amplitude.trackingQueue
        )

        add(plugin: IdentityEventSender())
    }
}
