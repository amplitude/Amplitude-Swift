import Foundation
import AnalyticsConnector

class AnalyticsConnectorPlugin: BeforePlugin {
    private static let EXPOSURE_EVENT = "$exposure"
    private var connector: AnalyticsConnector?

    override func setup(amplitude: Amplitude) {
        super.setup(amplitude: amplitude)
        connector = AnalyticsConnector.getInstance(amplitude.configuration.instanceName)
        connector!.eventBridge.setEventReceiver { event in
            amplitude.track(event: BaseEvent(
                eventType: event.eventType,
                eventProperties: event.eventProperties as? [String: Any],
                userProperties: event.userProperties as? [String: Any]
            ))
        }
    }

    override func execute(event: BaseEvent) -> BaseEvent? {
        guard let userProperties = event.userProperties else {
            return event
        }
        if userProperties.count == 0 || event.eventType == AnalyticsConnectorPlugin.EXPOSURE_EVENT {
            return event
        }
        connector?.identityStore.editIdentity().updateUserProperties(userProperties as NSDictionary).commit()
        return event
    }
}
