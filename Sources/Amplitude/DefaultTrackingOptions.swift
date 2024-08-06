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
            delegate?.didChangeSessions(to: sessions)
        }
    }

    public var appLifecycles: Bool {
        didSet {
            delegate?.didChangeAppLifecycles(to: appLifecycles)
        }
    }

    public var screenViews: Bool {
        didSet {
            delegate?.didChangeScreenViews(to: screenViews)
        }
    }

    weak var delegate: DefaultTrackingOptionsDelegate?

    var toAutocaptureOptions: AutocaptureOptions {
        return [
            sessions ? .sessions : [],
            appLifecycles ? .appLifecycles : [],
            screenViews ? .screenViews : []
        ].reduce(into: []) { $0.formUnion($1) }
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

    convenience init(with delegate: DefaultTrackingOptionsDelegate) {
        self.init()
        self.delegate = delegate
    }
}

protocol DefaultTrackingOptionsDelegate: AnyObject {
    func didChangeSessions(to newValue: Bool)
    func didChangeAppLifecycles(to newValue: Bool)
    func didChangeScreenViews(to newValue: Bool)
}

extension Configuration: DefaultTrackingOptionsDelegate {
    func didChangeSessions(to newValue: Bool) {
        updateAutocapture(option: .sessions, enabled: newValue)
    }

    func didChangeAppLifecycles(to newValue: Bool) {
        updateAutocapture(option: .appLifecycles, enabled: newValue)
    }

    func didChangeScreenViews(to newValue: Bool) {
        updateAutocapture(option: .screenViews, enabled: newValue)
    }

    private func updateAutocapture(option: AutocaptureOptions, enabled: Bool) {
        if enabled {
            autocapture.insert(option)
        } else {
            autocapture.remove(option)
        }
    }
}
