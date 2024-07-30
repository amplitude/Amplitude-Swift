import Foundation

@available(*, deprecated, renamed: "AutocaptureOptions", message: "Please use `AutocaptureOptions` instead")
public class DefaultTrackingOptions {
    public static var ALL: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: true, appLifecycles: true, screenViews: true)
    }
    public static var NONE: DefaultTrackingOptions {
        DefaultTrackingOptions(sessions: false, appLifecycles: false, screenViews: false)
    }

    public var sessions: Bool {
        didSet {
            autocapture?.sessions = sessions
        }
    }

    public var appLifecycles: Bool {
        didSet {
            autocapture?.sessions = appLifecycles
        }
    }

    public var screenViews: Bool {
        didSet {
            autocapture?.sessions = screenViews
        }
    }

    public init(
        sessions: Bool = true,
        appLifecycles: Bool = false,
        screenViews: Bool = false
    ) {
        self.sessions = sessions
        self.appLifecycles = appLifecycles
        self.screenViews = screenViews
    }

    private var autocapture: AutocaptureOptions?

    func withAutocptureOptions(_ autocapture: AutocaptureOptions) -> DefaultTrackingOptions {
        self.autocapture = autocapture
        return self
    }
}
