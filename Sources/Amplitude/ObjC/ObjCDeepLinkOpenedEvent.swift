import Foundation

@objc(AMPDeepLinkOpenedEvent)
public class ObjCDeepLinkOpenedEvent: ObjCBaseEvent {
    @objc(init:)
    public convenience init(activity: NSUserActivity) {
        self.init(event: DeepLinkOpenedEvent(activity: activity))
    }

    @objc(init:referrer:)
    public convenience init(url: String?, referrer: String? = nil) {
        self.init(event: DeepLinkOpenedEvent(url: url, referrer: referrer))
    }

    internal init(event: DeepLinkOpenedEvent) {
        super.init(event: event)
    }
}
