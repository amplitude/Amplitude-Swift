//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

@testable import AmplitudeSwift

final class EventPipelineTests: XCTestCase {
    private static let FLUSH_INTERVAL_SECONDS = 1.0

    private var configuration: Configuration!
    private var pipeline: EventPipeline!
    private var httpClient: FakeHttpClient!

    override func setUp() {
        super.setUp()
        let storage = FakeInMemoryStorage()
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            storageProvider: storage
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
    }

    func testInit() {
        XCTAssertEqual(pipeline.amplitude.configuration.apiKey, configuration.apiKey)
    }

    func testPutEvent() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")

        let eventExpectation = expectation(description: "Async function")
        pipeline.put(event: testEvent) {
            eventExpectation.fulfill()
        }
        XCTAssertEqual(testEvent.attempts, 1)

        let waitResult = XCTWaiter.wait(for: [eventExpectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(pipeline.eventCount, 1)
    }

    func testFlush() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let flushExpectation = expectation(description: "Async function")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        let waitResult = XCTWaiter.wait(for: [flushExpectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: httpClient.uploadedEvents[0])
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents![0].eventType, "testEvent")
    }
}
