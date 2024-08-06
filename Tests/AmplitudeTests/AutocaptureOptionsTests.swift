import XCTest

@testable import AmplitudeSwift

final class AutocaptureOptionsTests: XCTestCase {
    func testDefault() {
        let config = Configuration(apiKey: "TEST_KEY")
        XCTAssertFalse(config.autocapture.contains(.appLifecycles))
        XCTAssertFalse(config.autocapture.contains(.screenViews))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertFalse(config.autocapture.contains(.elementInteractions))
    }

    func testCustom() {
        let options: AutocaptureOptions = [.appLifecycles, .screenViews, .elementInteractions]
        XCTAssertTrue(options.contains(.appLifecycles))
        XCTAssertTrue(options.contains(.screenViews))
        XCTAssertFalse(options.contains(.sessions))
        XCTAssertTrue(options.contains(.elementInteractions))
    }

    func testDefaultTrackingOptionChangesReflectInAutocapture() {
        let configuration = Configuration(
            apiKey: "test-api-key"
        )

        XCTAssertTrue(configuration.autocapture.contains(.sessions))

        (configuration as DeprecationWarningDiscardable).setDefaultTrackingOptions(sessions: false, appLifecycles: true, screenViews: true)

        XCTAssertFalse(configuration.autocapture.contains(.sessions))
        XCTAssertTrue(configuration.autocapture.contains(.appLifecycles))
        XCTAssertTrue(configuration.autocapture.contains(.screenViews))
    }

    func testDefaultTrackingInstanceChangeReflectInAutocapture() {
        let configuration = Configuration(
            apiKey: "test-api-key"
        )

        (configuration as DeprecationWarningDiscardable).setDefaultTracking(sessions: false, appLifecycles: true, screenViews: true)

        XCTAssertFalse(configuration.autocapture.contains(.sessions))
        XCTAssertTrue(configuration.autocapture.contains(.appLifecycles))
        XCTAssertTrue(configuration.autocapture.contains(.screenViews))
    }
}

private protocol DeprecationWarningDiscardable {
    func setDefaultTracking(sessions: Bool, appLifecycles: Bool, screenViews: Bool)
    func setDefaultTrackingOptions(sessions: Bool, appLifecycles: Bool, screenViews: Bool)
}

extension Configuration: DeprecationWarningDiscardable {
    @available(*, deprecated)
    func setDefaultTracking(sessions: Bool, appLifecycles: Bool, screenViews: Bool) {
        defaultTracking = DefaultTrackingOptions(sessions: sessions, appLifecycles: appLifecycles, screenViews: screenViews)
    }

    @available(*, deprecated)
    func setDefaultTrackingOptions(sessions: Bool, appLifecycles: Bool, screenViews: Bool) {
        defaultTracking.sessions = sessions
        defaultTracking.appLifecycles = appLifecycles
        defaultTracking.screenViews = screenViews
    }
}
