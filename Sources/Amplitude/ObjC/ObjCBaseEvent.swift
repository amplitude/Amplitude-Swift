import Foundation

@objc(AMPBaseEvent)
public class ObjCBaseEvent: ObjCEventOptions {
    internal let event: BaseEvent

    internal override var options: EventOptions {
        event
    }

    @objc(initWithEventType:)
    public static func initWithEventType(eventType: String) -> ObjCBaseEvent {
        ObjCBaseEvent(eventType: eventType)
    }

    @objc(initWithEventType:eventProperties:)
    public static func initWithEventType(eventType: String, eventProperties: [String: Any]?) -> ObjCBaseEvent {
        ObjCBaseEvent(eventType: eventType, eventProperties: eventProperties)
    }

    @objc(initWithEventType:)
    public convenience init(eventType: String) {
        self.init(event: BaseEvent(eventType: eventType))
    }

    @objc(initWithEventType:eventProperties:)
    public convenience init(eventType: String, eventProperties: [String: Any]?) {
        self.init(event: BaseEvent(eventType: eventType, eventProperties: eventProperties))
    }

    internal init(event: BaseEvent) {
        self.event = event
    }

    @objc
    public var eventType: String {
        event.eventType
    }

    @objc
    public var eventProperties: ObjCProperties {
        ObjCProperties(setter: { (key, value) in
            if self.event.eventProperties == nil {
                self.event.eventProperties = [:]
            }
            self.event.eventProperties![key] = value
        }, remover: { key in
            self.event.eventProperties?.removeValue(forKey: key)
        })
    }

    @objc
    public var userProperties: ObjCProperties {
        ObjCProperties(setter: { (key, value) in
            if self.event.userProperties == nil {
                self.event.userProperties = [:]
            }
            self.event.userProperties![key] = value
        }, remover: { key in
            self.event.userProperties?.removeValue(forKey: key)
        })
    }

    @objc
    public var groups: ObjCProperties {
        ObjCProperties(setter: { (key, value) in
            if self.event.groups == nil {
                self.event.groups = [:]
            }
            self.event.groups![key] = value
        }, remover: { key in
            self.event.groups?.removeValue(forKey: key)
        })
    }

    @objc
    public var groupProperties: ObjCProperties {
        ObjCProperties(setter: { (key, value) in
            if self.event.groupProperties == nil {
                self.event.groupProperties = [:]
            }
            self.event.groupProperties![key] = value
        }, remover: { key in
            self.event.groupProperties?.removeValue(forKey: key)
        })
    }
}
