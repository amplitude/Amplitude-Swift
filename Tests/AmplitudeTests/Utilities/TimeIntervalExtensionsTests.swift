import XCTest
@testable import AmplitudeSwift

final class TimeIntervalExtensionsTests: XCTestCase {
    func testMilliseconds() {
        XCTAssertEqual(TimeInterval.milliseconds(1500), 1.5)
        XCTAssertEqual(TimeInterval.milliseconds(250), 0.25)
    }

    func testHoursAndDays() {
        XCTAssertEqual(TimeInterval.hours(1), 3600)
        XCTAssertEqual(TimeInterval.days(1), 86400)
    }
}
