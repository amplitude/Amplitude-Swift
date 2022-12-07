//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

@testable import Amplitude_Swift

final class EventPipelineTests: XCTestCase {
    private var configuration: Configuration!
    private var amplitude: Amplitude!
    private var eventPipeline: EventPipeline!

    override func setUp() {
        super.setUp()
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: 1000,
            storageProvider: FakeInMemoryStorage()
        )
        amplitude = Amplitude(configuration: configuration)
        eventPipeline = EventPipeline(amplitude: amplitude)
    }

    func testInit() {
        XCTAssertEqual(eventPipeline.amplitude.configuration.apiKey, amplitude.configuration.apiKey)
    }

    func testPutEvent() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")

        let asyncExpectation = expectation(description: "Async function")
        eventPipeline.put(event: testEvent) {
            asyncExpectation.fulfill()
            XCTAssertEqual(self.eventPipeline.eventCount, 1)
        }
        XCTAssertEqual(testEvent.attempts, 1)
        _ = XCTWaiter.wait(for: [asyncExpectation], timeout: 3)
    }

    func testFlush() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? eventPipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let fakeHttpClient = FakeHttpClient(configuration: configuration)
        eventPipeline.httpClient = fakeHttpClient as HttpClient

        let asyncExpectation = expectation(description: "Async function")
        eventPipeline.flush {
            asyncExpectation.fulfill()
            XCTAssertEqual(fakeHttpClient.isUploadCalled, true)
        }
        _ = XCTWaiter.wait(for: [asyncExpectation], timeout: 3)
    }
}
