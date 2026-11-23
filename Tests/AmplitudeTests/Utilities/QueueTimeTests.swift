import XCTest

@testable import AmplitudeSwift

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
        timer?.stop()
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(currentExpectationIndex, expectations.count)
    }

    func testOverdueTickWaitsForRestartAndFiresOnce() {
        let queue = DispatchQueue(label: "QueueTimerTests")
        let fired = expectation(description: "overdue tick delivered on restart")
        fired.assertForOverFulfill = true
        var timer: QueueTimer?
        var restarted = false
        queue.sync {
            timer = QueueTimer(interval: 0.1, once: true, queue: queue) {
                XCTAssertTrue(restarted)
                fired.fulfill()
            }
            Thread.sleep(forTimeInterval: 0.2) // The tick is due on this occupied queue.
            timer?.stop()
            timer?.stop()
        }
        queue.sync {
            restarted = true
            timer?.start()
            timer?.start()
        }
        wait(for: [fired], timeout: 2)
        queue.sync { timer?.stop() }
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
        timer?.stop()
        XCTAssertEqual(waitResult, .timedOut)
        XCTAssertEqual(currentExpectationIndex, 1)
    }
}
