import Foundation

extension Bundle {
    /// `Bundle` reference based on environment.
    ///
    /// If the **SWIFT_CLI** compiler flag is present, the default `.module` bundle should be available.
    static var testBundle: Bundle {
        #if SWIFT_CLI
        return .module
        #else
        return Bundle(for: AmplitudeTests.self)
        #endif
    }
}
