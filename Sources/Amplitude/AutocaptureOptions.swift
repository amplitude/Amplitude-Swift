import Foundation

public struct AutocaptureOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sessions            = AutocaptureOptions(rawValue: 1 << 0)
    @available(*, deprecated, message: "Please use `installLifecycle` and `foregroundLifecycle` instead.")
    public static let appLifecycles       = AutocaptureOptions(rawValue: 1 << 1)
    public static let screenViews         = AutocaptureOptions(rawValue: 1 << 2)
    public static let elementInteractions = AutocaptureOptions(rawValue: 1 << 3)
    /// Won't work on watchOS
    public static let networkTracking     = AutocaptureOptions(rawValue: 1 << 4)
    /// Rage Click and Dead Click detection
    public static let frustrationInteractions = AutocaptureOptions(rawValue: 1 << 5)
    /// Application installed and updated events
    public static let installLifecycle = AutocaptureOptions(rawValue: 1 << 6)
    /// Application opened and backgrounded events
    public static let foregroundLifecycle = AutocaptureOptions(rawValue: 1 << 7)

    public static let all: AutocaptureOptions = [
        .sessions,
        .legacyAppLifecycles,
        .screenViews,
        .elementInteractions,
        .networkTracking,
        .frustrationInteractions,
        .installLifecycle,
        .foregroundLifecycle,
    ]

    // For internal use only, to avoid the deprecation warnings.
    static let legacyAppLifecycles = AutocaptureOptions(rawValue: 1 << 1)
}

extension AutocaptureOptions {
    func stringRepresentation() -> String {
        guard rawValue != 0 else { return "none" }

        var options: [String] = []

        if contains(.sessions) {
            options.append("sessions")
        }
        if contains(.legacyAppLifecycles) {
            options.append("appLifecycles")
        }
        if contains(.screenViews) {
            options.append("screenViews")
        }
        if contains(.elementInteractions) {
            options.append("elementInteractions")
        }
        if contains(.networkTracking) {
            options.append("networkTracking")
        }
        if contains(.frustrationInteractions) {
            options.append("frustrationInteractions")
        }
        if contains(.installLifecycle) {
            options.append("installLifecycle")
        }
        if contains(.foregroundLifecycle) {
            options.append("foregroundLifecycle")
        }

        return options.joined(separator: ",")
    }

    func withNormalizedAppLifecycles() -> AutocaptureOptions {
        guard contains(.legacyAppLifecycles) else {
            return self
        }
        var normalized = self
        normalized.subtract(.legacyAppLifecycles)
        normalized.formUnion([.installLifecycle, .foregroundLifecycle])
        return normalized
    }
}
