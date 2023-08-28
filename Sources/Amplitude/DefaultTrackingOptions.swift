import Foundation

public class DefaultTrackingOptions {
    public static var ALL: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: true, appLifecycles: true, deepLinks: true, screenViews: true)
    }
    public static var NONE: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: false, appLifecycles: false, deepLinks: false, screenViews: false)
    }

    public var sessions: Bool = true
    public var appLifecycles: Bool
    public var deepLinks: Bool
    public var screenViews: Bool

    public init(
        sessions: Bool = true,
        appLifecycles: Bool = false,
        deepLinks: Bool = false,
        screenViews: Bool = false
    ) {
        self.sessions = sessions
        self.appLifecycles = appLifecycles
        self.deepLinks = deepLinks
        self.screenViews = screenViews
    }
}
