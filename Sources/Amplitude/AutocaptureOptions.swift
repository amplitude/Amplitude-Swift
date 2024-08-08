import Foundation

public struct AutocaptureOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sessions            = AutocaptureOptions(rawValue: 1 << 0)
    public static let appLifecycles       = AutocaptureOptions(rawValue: 1 << 1)
    public static let screenViews         = AutocaptureOptions(rawValue: 1 << 2)
    public static let elementInteractions = AutocaptureOptions(rawValue: 1 << 3)
}
