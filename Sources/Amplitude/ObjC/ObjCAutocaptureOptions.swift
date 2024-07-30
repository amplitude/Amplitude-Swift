import Foundation

@objc(AMPAutocaptureOptions)
public class ObjCAutocaptureOptions: NSObject {
    internal let options: AutocaptureOptions

    @objc
    convenience public override init() {
        self.init(AutocaptureOptions())
    }

    internal init(_ options: AutocaptureOptions) {
        self.options = options
    }

    @objc
    public var sessions: Bool {
        get {
            options.sessions
        }
        set(value) {
            options.sessions = value
        }
    }

    @objc
    public var appLifecycles: Bool {
        get {
            options.appLifecycles
        }
        set(value) {
            options.appLifecycles = value
        }
    }

    @objc
    public var screenViews: Bool {
        get {
            options.screenViews
        }
        set(value) {
            options.screenViews = value
        }
    }

    @objc
    public var elementInteractions: Bool {
        get {
            options.elementInteractions
        }
        set(value) {
            options.elementInteractions = value
        }
    }
}
