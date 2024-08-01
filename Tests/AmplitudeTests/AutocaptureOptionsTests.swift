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
}
