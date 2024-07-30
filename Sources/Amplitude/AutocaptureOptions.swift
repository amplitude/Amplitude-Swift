import Foundation

public class AutocaptureOptions {
    public var sessions: Bool = true
    public var appLifecycles: Bool
    public var screenViews: Bool
    public var elementInteractions: Bool

    public init(
        sessions: Bool = true,
        appLifecycles: Bool = false,
        screenViews: Bool = false,
        elementInteractions: Bool = false
    ) {
        self.sessions = sessions
        self.appLifecycles = appLifecycles
        self.screenViews = screenViews
        self.elementInteractions = elementInteractions
    }
}
