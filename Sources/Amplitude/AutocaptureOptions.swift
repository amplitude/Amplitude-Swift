import Foundation

public struct AutocaptureOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        // In case someone persisted a raw value and is reconstructing an `AutocaptureOptions` from it.
        let legacyAppLifecycles = 1 << 1
        if rawValue & legacyAppLifecycles != 0 {
            assertionFailure("The legacy appLifecycles bit should no longer be used.")
            self.rawValue = (rawValue & ~legacyAppLifecycles) | AutocaptureOptions.appLifecycles.rawValue
        } else {
            self.rawValue = rawValue
        }
    }

    public static let sessions            = AutocaptureOptions(rawValue: 1 << 0)
    public static let screenViews         = AutocaptureOptions(rawValue: 1 << 2)
    public static let elementInteractions = AutocaptureOptions(rawValue: 1 << 3)
    /// Won't work on watchOS
    public static let networkTracking     = AutocaptureOptions(rawValue: 1 << 4)
    /// Rage Click and Dead Click detection
    public static let frustrationInteractions = AutocaptureOptions(rawValue: 1 << 5)
    /// Application installed and updated events
    public static let installLifecycle    = AutocaptureOptions(rawValue: 1 << 6)
    /// Application opened and backgrounded events
    public static let foregroundLifecycle = AutocaptureOptions(rawValue: 1 << 7)

    /// Union of install and foreground lifecycles
    public static let appLifecycles: AutocaptureOptions = [.installLifecycle, .foregroundLifecycle]

    public static let all: AutocaptureOptions = [
        .sessions,
        .installLifecycle,
        .foregroundLifecycle,
        .screenViews,
        .elementInteractions,
        .networkTracking,
        .frustrationInteractions,
    ]
}

extension AutocaptureOptions {
    func stringRepresentation() -> String {
        guard rawValue != 0 else { return "none" }

        var options: [String] = []

        if contains(.sessions) {
            options.append("sessions")
        }
        if contains(.appLifecycles) {
            options.append("appLifecycles")
        } else {
            if contains(.installLifecycle) {
                options.append("installLifecycle")
            }
            if contains(.foregroundLifecycle) {
                options.append("foregroundLifecycle")
            }
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

        return options.joined(separator: ",")
    }
}
