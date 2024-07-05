import XCTest

@testable import AmplitudeSwift

final class DefaultTrackingOptionsTests: XCTestCase {
    func testDefault() {
        let options = DefaultTrackingOptions()
        XCTAssertFalse(options.appLifecycles)
        XCTAssertFalse(options.screenViews)
        XCTAssertTrue(options.sessions)
        XCTAssertFalse(options.userInteractions)
    }

    func testAll() {
        let options = DefaultTrackingOptions.ALL
        XCTAssertTrue(options.appLifecycles)
        XCTAssertTrue(options.screenViews)
        XCTAssertTrue(options.sessions)
        XCTAssertFalse(options.userInteractions)
    }

    func testNone() {
        let options = DefaultTrackingOptions.NONE
        XCTAssertFalse(options.appLifecycles)
        XCTAssertFalse(options.screenViews)
        XCTAssertFalse(options.sessions)
        XCTAssertFalse(options.userInteractions)
    }

    func testCustom() {
        let options = DefaultTrackingOptions(sessions: false, appLifecycles: true, screenViews: true, userInteractions: true)
        XCTAssertTrue(options.appLifecycles)
        XCTAssertTrue(options.screenViews)
        XCTAssertFalse(options.sessions)
        XCTAssertTrue(options.userInteractions)
    }
}
