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
            if sessions {
                autocapture?.insert(.sessions)
            } else {
                autocapture?.remove(.sessions)
            }
        }
    }

    public var appLifecycles: Bool {
        didSet {
            if appLifecycles {
                autocapture?.insert(.appLifecycles)
            } else {
                autocapture?.remove(.appLifecycles)
            }
        }
    }

    public var screenViews: Bool {
        didSet {
            if screenViews {
                autocapture?.insert(.screenViews)
            } else {
                autocapture?.remove(.screenViews)
            }
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
