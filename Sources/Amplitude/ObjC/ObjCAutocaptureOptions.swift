import Foundation

@objc(AMPAutocaptureOptions)
public final class ObjCAutocaptureOptions: NSObject {
    internal var _options: AutocaptureOptions

    public override init() {
        _options = AutocaptureOptions()
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
        self.init()
        _options = options
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
        return ObjCAutocaptureOptions(options: .sessions)
    }

    @objc
    public static func appLifecycles() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(options: .appLifecycles)
    }

    @objc
    public static func screenViews() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(options: .screenViews)
    }

    @objc
    public static func elementInteractions() -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(options: .elementInteractions)
    }

    // MARK: NSObject

    public override var hash: Int {
        return _options.rawValue
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let that = object as? ObjCAutocaptureOptions else {
            return false
        }
        return _options == that._options
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
        return ObjCAutocaptureOptions(options: _options.union(option._options))
    }

    @objc
    public func intersect(_ option: ObjCAutocaptureOptions) -> ObjCAutocaptureOptions {
        return ObjCAutocaptureOptions(options: _options.intersection(option._options))
    }
}
