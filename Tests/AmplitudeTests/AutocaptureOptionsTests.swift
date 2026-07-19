import XCTest

@testable import AmplitudeSwift

final class AutocaptureOptionsTests: XCTestCase {
    func testDefault() {
        let config = Configuration(apiKey: "TEST_KEY")
        XCTAssertFalse(config.autocapture.contains(.legacyAppLifecycles))
        XCTAssertFalse(config.autocapture.contains(.installLifecycle))
        XCTAssertFalse(config.autocapture.contains(.foregroundLifecycle))
        XCTAssertFalse(config.autocapture.contains(.screenViews))
        XCTAssertTrue(config.autocapture.contains(.sessions))
        XCTAssertFalse(config.autocapture.contains(.elementInteractions))
#if !os(watchOS)
        XCTAssertFalse(config.autocapture.contains(.networkTracking))
#endif
    }

    func testCustom() {
        let options: AutocaptureOptions = [.legacyAppLifecycles, .screenViews, .elementInteractions]
        XCTAssertTrue(options.contains(.legacyAppLifecycles))
        XCTAssertFalse(options.contains(.installLifecycle))
        XCTAssertFalse(options.contains(.foregroundLifecycle))
        XCTAssertTrue(options.contains(.screenViews))
        XCTAssertFalse(options.contains(.sessions))
        XCTAssertTrue(options.contains(.elementInteractions))
#if !os(watchOS)
        XCTAssertFalse(options.contains(.networkTracking))
#endif
    }

    @available(*, deprecated)
    func testAppLifecyclesEqualsLegacyAppLifecycles() {
        XCTAssertEqual(AutocaptureOptions.appLifecycles, .legacyAppLifecycles)
    }

    func testAppLifecyclesNormalizesToDistinctOptionsForInternalUse() {
        // Simulate an existing binary or persisted value produced before the lifecycle split.
        let options = AutocaptureOptions(rawValue: (1 << 0) | (1 << 1))
        let normalized = options.withNormalizedAppLifecycles()

        XCTAssertTrue(options.contains(.sessions))
        XCTAssertTrue(options.contains(.legacyAppLifecycles))
        XCTAssertFalse(options.contains(.installLifecycle))
        XCTAssertFalse(options.contains(.foregroundLifecycle))

        XCTAssertTrue(normalized.contains(.sessions))
        XCTAssertFalse(normalized.contains(.legacyAppLifecycles))
        XCTAssertTrue(normalized.contains(.installLifecycle))
        XCTAssertTrue(normalized.contains(.foregroundLifecycle))
    }

    func testAllIncludesDistinctLifecycleOptions() {
        XCTAssertTrue(AutocaptureOptions.all.contains(.legacyAppLifecycles))
        XCTAssertTrue(AutocaptureOptions.all.contains(.installLifecycle))
        XCTAssertTrue(AutocaptureOptions.all.contains(.foregroundLifecycle))
    }

    func testDistinctLifecycleOptionsStringRepresentation() {
        XCTAssertEqual(AutocaptureOptions.installLifecycle.stringRepresentation(), "installLifecycle")
        XCTAssertEqual(AutocaptureOptions.foregroundLifecycle.stringRepresentation(), "foregroundLifecycle")
        XCTAssertEqual(
            AutocaptureOptions([.installLifecycle, .foregroundLifecycle]).stringRepresentation(),
            "installLifecycle,foregroundLifecycle"
        )
        XCTAssertEqual(
            AutocaptureOptions([.legacyAppLifecycles, .installLifecycle, .foregroundLifecycle]).stringRepresentation(),
            "appLifecycles,installLifecycle,foregroundLifecycle"
        )
    }

    func testRawValuesPreserveExistingOptions() {
        XCTAssertEqual(AutocaptureOptions.sessions.rawValue, 1 << 0)
        XCTAssertEqual(AutocaptureOptions.legacyAppLifecycles.rawValue, 1 << 1)
        XCTAssertEqual(AutocaptureOptions.screenViews.rawValue, 1 << 2)
        XCTAssertEqual(AutocaptureOptions.elementInteractions.rawValue, 1 << 3)
        XCTAssertEqual(AutocaptureOptions.networkTracking.rawValue, 1 << 4)
        XCTAssertEqual(AutocaptureOptions.frustrationInteractions.rawValue, 1 << 5)
        XCTAssertEqual(AutocaptureOptions.installLifecycle.rawValue, 1 << 6)
        XCTAssertEqual(AutocaptureOptions.foregroundLifecycle.rawValue, 1 << 7)
    }

    func testObjCLifecycleOptions() {
        let legacyAppLifecycles = ObjCAutocaptureOptions(options: .legacyAppLifecycles)

        XCTAssertTrue(legacyAppLifecycles.contains(legacyAppLifecycles))
        XCTAssertTrue(ObjCAutocaptureOptions.installLifecycle.contains(.installLifecycle))
        XCTAssertTrue(ObjCAutocaptureOptions.foregroundLifecycle.contains(.foregroundLifecycle))
        XCTAssertFalse(legacyAppLifecycles.contains(.installLifecycle))
        XCTAssertFalse(legacyAppLifecycles.contains(.foregroundLifecycle))
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
        XCTAssertTrue(configuration.autocapture.contains(.legacyAppLifecycles))
        XCTAssertFalse(configuration.autocapture.contains(.installLifecycle))
        XCTAssertFalse(configuration.autocapture.contains(.foregroundLifecycle))
        XCTAssertTrue(configuration.autocapture.contains(.screenViews))
    }

    func testDefaultTrackingInstanceChangeReflectInAutocapture() {
        let configuration = Configuration(
            apiKey: "test-api-key"
        )

        (configuration as DeprecationWarningDiscardable).setDefaultTracking(sessions: false, appLifecycles: true, screenViews: true)

        XCTAssertFalse(configuration.autocapture.contains(.sessions))
        XCTAssertTrue(configuration.autocapture.contains(.legacyAppLifecycles))
        XCTAssertFalse(configuration.autocapture.contains(.installLifecycle))
        XCTAssertFalse(configuration.autocapture.contains(.foregroundLifecycle))
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
