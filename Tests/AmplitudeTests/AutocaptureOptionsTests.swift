import XCTest

@testable import AmplitudeSwift

final class AutocaptureOptionsTests: XCTestCase {
    func testDefault() {
        let config = Configuration(apiKey: "TEST_KEY")
        XCTAssertFalse(config.autocapture.contains(.appLifecycles))
        XCTAssertFalse(config.autocapture.contains(.screenViews))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertFalse(config.autocapture.contains(.elementInteractions))
#if !os(watchOS)
        XCTAssertFalse(config.autocapture.contains(.networkTracking))
#endif
    }

    func testCustom() {
        let options: AutocaptureOptions = [.appLifecycles, .screenViews, .elementInteractions]
        XCTAssertTrue(options.contains(.appLifecycles))
        XCTAssertTrue(options.contains(.installLifecycle))
        XCTAssertTrue(options.contains(.foregroundLifecycle))
        XCTAssertTrue(options.contains(.screenViews))
        XCTAssertFalse(options.contains(.sessions))
        XCTAssertTrue(options.contains(.elementInteractions))
#if !os(watchOS)
        XCTAssertFalse(options.contains(.networkTracking))
#endif
    }

    func testAppLifecyclesContainsBothLifecycleOptions() {
        XCTAssertEqual(AutocaptureOptions.appLifecycles, [.installLifecycle, .foregroundLifecycle])
    }

    func testAllIncludesDistinctLifecycleOptions() {
        XCTAssertTrue(AutocaptureOptions.all.contains(.installLifecycle))
        XCTAssertTrue(AutocaptureOptions.all.contains(.foregroundLifecycle))
    }

    func testDistinctLifecycleOptionsStringRepresentation() {
        XCTAssertEqual(AutocaptureOptions.installLifecycle.stringRepresentation(), "installLifecycle")
        XCTAssertEqual(AutocaptureOptions.foregroundLifecycle.stringRepresentation(), "foregroundLifecycle")
        XCTAssertEqual(
            AutocaptureOptions([.installLifecycle, .foregroundLifecycle]).stringRepresentation(),
            "appLifecycles"
        )
    }

    func testObjCLifecycleOptions() {
        XCTAssertTrue(ObjCAutocaptureOptions.installLifecycle.contains(.installLifecycle))
        XCTAssertTrue(ObjCAutocaptureOptions.foregroundLifecycle.contains(.foregroundLifecycle))
        XCTAssertFalse(ObjCAutocaptureOptions.installLifecycle.contains(.foregroundLifecycle))
        XCTAssertFalse(ObjCAutocaptureOptions.foregroundLifecycle.contains(.installLifecycle))
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
