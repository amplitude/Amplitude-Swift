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
    /// Won't work on watchOS
    public static let networkTracking     = AutocaptureOptions(rawValue: 1 << 4)
    /// Rage Click and Dead Click detection
    @_spi(Frustration)
    public static let frustrationInteractions = AutocaptureOptions(rawValue: 1 << 5)

    public static let all: AutocaptureOptions = [
        .sessions,
        .appLifecycles,
        .screenViews,
        .elementInteractions,
        .networkTracking
    ]
}
