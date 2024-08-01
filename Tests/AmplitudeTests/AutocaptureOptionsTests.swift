import XCTest

@testable import AmplitudeSwift

final class AutocaptureOptionsTests: XCTestCase {
    func testDefault() {
        let options = AutocaptureOptions()
        XCTAssertFalse(options.contains(.appLifecycles))
        XCTAssertFalse(options.contains(.screenViews))
        XCTAssertTrue(options.contains(.sessions))
        XCTAssertFalse(options.contains(.elementInteractions))
    }

    func testCustom() {
        let options: AutocaptureOptions = [.appLifecycles, .screenViews, .elementInteractions]
        XCTAssertTrue(options.contains(.appLifecycles))
        XCTAssertTrue(options.contains(.screenViews))
        XCTAssertFalse(options.contains(.sessions))
        XCTAssertTrue(options.contains(.elementInteractions))
    }
}
