import XCTest

@testable import AmplitudeSwift

final class DefaultTrackingOptionsTests: XCTestCase {
    func testDefault() {
        let options = DefaultTrackingOptions()
        XCTAssertFalse(options.appLifecycles)
        XCTAssertFalse(options.deepLinks)
        XCTAssertFalse(options.screenViews)
        XCTAssertTrue(options.sessions)
    }

    func testAll() {
        let options = DefaultTrackingOptions.ALL
        XCTAssertTrue(options.appLifecycles)
        XCTAssertTrue(options.deepLinks)
        XCTAssertTrue(options.screenViews)
        XCTAssertTrue(options.sessions)
    }

    func testNone() {
        let options = DefaultTrackingOptions.NONE
        XCTAssertFalse(options.appLifecycles)
        XCTAssertFalse(options.deepLinks)
        XCTAssertFalse(options.screenViews)
        XCTAssertFalse(options.sessions)
    }

    func testCustom() {
        let options = DefaultTrackingOptions(sessions: false, appLifecycles: true, deepLinks: false, screenViews: true)
        XCTAssertTrue(options.appLifecycles)
        XCTAssertFalse(options.deepLinks)
        XCTAssertTrue(options.screenViews)
        XCTAssertFalse(options.sessions)
    }
}
