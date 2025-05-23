import XCTest
@testable import AmplitudeSwift

final class TimeIntervalExtensionsTests: XCTestCase {
    func testMilliseconds() {
        XCTAssertEqual(TimeInterval.milliseconds(1500), 1.5)
        XCTAssertEqual(TimeInterval.milliseconds(250), 0.25)
    }

}
