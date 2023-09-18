import Foundation

@objc(AMPScreenViewEvent)
public class ObjCScreenViewedEvent: ObjCBaseEvent {
    @objc(init:)
    public convenience init(screenName: String) {
        self.init(event: ScreenViewedEvent(screenName: screenName))
    }
}
