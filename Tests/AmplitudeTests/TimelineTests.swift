import Foundation
import XCTest

@testable import Amplitude_Swift

final class TimelineTests: XCTestCase {
    private var timeline: Timeline!

    func testTimeline() {
        let expectation = XCTestExpectation(description: "First Plugin")
        let testPlugin = TestEnrichmentPlugin {
            expectation.fulfill()
            return true
        }

        let amplitude = Amplitude(configuration: Configuration(apiKey: "testApiKey"))
        amplitude.add(plugin: testPlugin)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))

        wait(for: [expectation], timeout: 1.0)
    }

    func testTimelineWithTwoPlugin() {
        let expectation = XCTestExpectation(description: "First Plugin")
        let expectation2 = XCTestExpectation(description: "Second Plugin")
        let testPlugin = TestEnrichmentPlugin {
            expectation.fulfill()
            return true
        }

        let testPlugin2 = TestEnrichmentPlugin {
            expectation2.fulfill()
            return true
        }

        let amplitude = Amplitude(configuration: Configuration(apiKey: "testApiKey"))
        amplitude.add(plugin: testPlugin)
        amplitude.add(plugin: testPlugin2)
        amplitude.track(event: BaseEvent(eventType: "testEvent"))

        wait(for: [expectation, expectation2], timeout: 1.0)
    }
}
