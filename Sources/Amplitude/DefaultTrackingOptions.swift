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
        get {
            autocaptureOptions.contains(.sessions)
        }
        set {
            if newValue {
                autocaptureOptions.insert(.sessions)
            } else {
                autocaptureOptions.remove(.sessions)
            }
        }
    }

    public var appLifecycles: Bool {
        get {
            autocaptureOptions.contains(.appLifecycles)
        }
        set {
            if newValue {
                autocaptureOptions.insert(.appLifecycles)
            } else {
                autocaptureOptions.remove(.appLifecycles)
            }
        }
    }

    public var screenViews: Bool {
        get {
            autocaptureOptions.contains(.screenViews)
        }
        set {
            if newValue {
                autocaptureOptions.insert(.screenViews)
            } else {
                autocaptureOptions.remove(.screenViews)
            }
        }
    }

    var autocaptureOptions: AutocaptureOptions

    public init(
        sessions: Bool = true,
        appLifecycles: Bool = false,
        screenViews: Bool = false
    ) {
        self.autocaptureOptions = []
        self.sessions = sessions
        self.appLifecycles = appLifecycles
        self.screenViews = screenViews
    }
}
