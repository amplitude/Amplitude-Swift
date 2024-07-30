import XCTest

@testable import AmplitudeSwift

final class AutocaptureOptionsTests: XCTestCase {
    func testDefault() {
        let options = AutocaptureOptions()
        XCTAssertFalse(options.appLifecycles)
        XCTAssertFalse(options.screenViews)
        XCTAssertTrue(options.sessions)
        XCTAssertFalse(options.elementInteractions)
    }

    func testCustom() {
        let options = AutocaptureOptions(sessions: false, appLifecycles: true, screenViews: true, elementInteractions: true)
        XCTAssertTrue(options.appLifecycles)
        XCTAssertTrue(options.screenViews)
        XCTAssertFalse(options.sessions)
        XCTAssertTrue(options.elementInteractions)
    }
}
