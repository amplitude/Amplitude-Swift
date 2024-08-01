import Foundation

@objc(AMPAutocaptureOptions)
public final class ObjCAutocaptureOptions: NSObject, OptionSet {
    internal var _options: AutocaptureOptions

    public var rawValue: Int {
        get {
            return _options.rawValue
        }
        set {
            _options = AutocaptureOptions(rawValue: newValue)
        }
    }

    public override init() {
        _options = AutocaptureOptions()
        super.init()
    }

    public init(rawValue: Int) {
        _options = AutocaptureOptions(rawValue: rawValue)
        super.init()
    }

    @objc
    public convenience init(optionsToUnion: [ObjCAutocaptureOptions]) {
        self.init()
        for option in optionsToUnion {
            formUnion(option)
        }
    }

    internal convenience init(options: AutocaptureOptions) {
        self.init(rawValue: options.rawValue)
    }

    internal var options: AutocaptureOptions {
        get {
            return _options
        }
        set {
            _options = newValue
        }
    }

    @objc
    public static func sessions() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(rawValue: AutocaptureOptions.sessions.rawValue)
    }

    @objc
    public static func appLifecycles() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(rawValue: AutocaptureOptions.appLifecycles.rawValue)
    }

    @objc
    public static func screenViews() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(rawValue: AutocaptureOptions.screenViews.rawValue)
    }

    @objc
    public static func elementInteractions() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(rawValue: AutocaptureOptions.elementInteractions.rawValue)
    }

    // MARK: NSObject

    public override var hash: Int {
        return _options.rawValue
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let that = object as? ObjCAutocaptureOptions else {
            return false
        }
        return _options.rawValue == that._options.rawValue
    }

    // MARK: OptionSet-like behavior

    @objc
    public func formUnion(_ other: ObjCAutocaptureOptions) {
        _options.formUnion(other._options)
    }

    @objc
    public func formIntersection(_ other: ObjCAutocaptureOptions) {
        _options.formIntersection(other._options)
    }

    @objc
    public func formSymmetricDifference(_ other: ObjCAutocaptureOptions) {
        _options.formSymmetricDifference(other._options)
    }

    // MARK: Convenience methods for Objective-C

    @objc
    public func contains(_ option: ObjCAutocaptureOptions) -> Bool {
        return _options.contains(option._options)
    }

    @objc
    public func union(_ option: ObjCAutocaptureOptions) -> ObjCAutocaptureOptions {
        let result = ObjCAutocaptureOptions()
        result._options = self._options.union(option._options)
        return result
    }

    @objc
    public func intersect(_ option: ObjCAutocaptureOptions) -> ObjCAutocaptureOptions {
        let result = ObjCAutocaptureOptions()
        result._options = self._options.intersection(option._options)
        return result
    }
}
