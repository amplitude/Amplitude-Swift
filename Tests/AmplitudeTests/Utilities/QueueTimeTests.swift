import XCTest

@testable import Amplitude_Swift

final class QueueTimerTests: XCTestCase {
    func testRepeat() {
        let expectations = [
            XCTestExpectation(description: "tick 1"),
            XCTestExpectation(description: "tick 2"),
            XCTestExpectation(description: "tick 3")
        ]
        var currentExpectationIndex: Int = 0
        let timer: QueueTimer? = QueueTimer(interval: TimeInterval.milliseconds(100)) {
            if currentExpectationIndex < expectations.count {
                expectations[currentExpectationIndex].fulfill()
                currentExpectationIndex += 1
            }
        }

        let waitResult = XCTWaiter.wait(for: expectations, timeout: 1)
        timer?.suspend()
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(currentExpectationIndex, expectations.count)
    }

    func testOnce() {
        let expectations = [
            XCTestExpectation(description: "tick 1"),
            XCTestExpectation(description: "tick 2"),
            XCTestExpectation(description: "tick 3")
        ]
        var currentExpectationIndex: Int = 0
        let timer: QueueTimer? = QueueTimer(interval: TimeInterval.milliseconds(100), once: true) {
            if currentExpectationIndex < expectations.count {
                expectations[currentExpectationIndex].fulfill()
                currentExpectationIndex += 1
            }
        }

        let waitResult = XCTWaiter.wait(for: expectations, timeout: 1)
        timer?.suspend()
        XCTAssertEqual(waitResult, .timedOut)
        XCTAssertEqual(currentExpectationIndex, 1)
    }
}
