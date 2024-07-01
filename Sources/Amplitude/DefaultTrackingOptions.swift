import Foundation

public class DefaultTrackingOptions {
    public static var ALL: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: true, appLifecycles: true, screenViews: true)
    }
    public static var NONE: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: false, appLifecycles: false, screenViews: false)
    }

    public var sessions: Bool = true
    public var appLifecycles: Bool
    public var screenViews: Bool
    public var userInteractions: Bool

    public init(
        sessions: Bool = true,
        appLifecycles: Bool = false,
        screenViews: Bool = false
    ) {
        self.sessions = sessions
        self.appLifecycles = appLifecycles
        self.screenViews = screenViews
        self.userInteractions = false
    }
    
    public convenience init (
        sessions: Bool = true,
        appLifecycles: Bool = false,
        screenViews: Bool = false,
        userInteractions: Bool = false
    ) {
        self.init(sessions: sessions, appLifecycles: appLifecycles, screenViews: screenViews)
        self.userInteractions = userInteractions
    }
}
