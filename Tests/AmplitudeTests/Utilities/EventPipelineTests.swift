//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

@testable import AmplitudeSwift

final class EventPipelineTests: XCTestCase {
    private static let FLUSH_INTERVAL_SECONDS = 10.0

    private var configuration: Configuration!
    private var pipeline: EventPipeline!
    private var httpClient: FakeHttpClient!
    private var storage: PersistentStorage!

    override func setUp() {
        super.setUp()
        storage = PersistentStorage(
            storagePrefix: "event-pipeline-tests",
            logger: nil,
            diagonostics: Diagnostics())
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            storageProvider: storage,
            offline: NetworkConnectivityCheckerPlugin.Disabled
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration, diagnostics: configuration.diagonostics)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        pipeline.flushTimer?.suspend()

    }

    override func tearDown() {
        super.tearDown()
        storage.reset()
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

    func testFlushWhenOffline() {
        pipeline.amplitude.configuration.offline = false

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(pipeline.amplitude.configuration.offline, false)

        pipeline.amplitude.configuration.offline = true
        pipeline.flush()

        XCTAssertEqual(pipeline.amplitude.configuration.offline, true)
        XCTAssertEqual(httpClient.uploadCount, 0, "There should be no uploads when offline")
    }

    func testSimultaneousFlush() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let httpResponseExpectation = expectation(description: "httpresponse")
        httpClient.uploadExpectations = [httpResponseExpectation]

        let flushExpectations = (0..<2).map { _ in
            let expectation = expectation(description: "flush")
            pipeline.flush {
                expectation.fulfill()
            }
            return expectation
        }

        wait(for: flushExpectations, timeout: 1)
        wait(for: [httpResponseExpectation], timeout: 1)

        XCTAssertEqual(httpClient.uploadCount, 1)
        let uploadedEvents = BaseEvent.fromArrayString(jsonString: httpClient.uploadedEvents[0])
        XCTAssertEqual(uploadedEvents?.count, 1)
        XCTAssertEqual(uploadedEvents![0].eventType, "testEvent")
    }

    func testInvalidEventUpload() {
        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!

        httpClient.uploadResults = [
            .failure(HttpClient.Exception.httpError(code: 400, data: invalidResponseData))
        ]

        let uploadExpectations = (0..<2).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        (0..<2).forEach { i in
            let testEvent = BaseEvent(userId: "test", deviceId: "test-machine", eventType: "testEvent-\(i)")
            try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)
        }

        let flushExpectation1 = expectation(description: "flush-1")
        pipeline.flush {
            flushExpectation1.fulfill()
        }
        wait(for: [uploadExpectations[0], flushExpectation1], timeout: 1)

        let flushExpectation2 = expectation(description: "flush-2")
        pipeline.flush {
            flushExpectation2.fulfill()
        }
        wait(for: [uploadExpectations[1], flushExpectation2], timeout: 1)

        XCTAssertEqual(httpClient.uploadCount, 2)

        let uploadedEvents0 = BaseEvent.fromArrayString(jsonString: httpClient.uploadedEvents[0])
        XCTAssertEqual(uploadedEvents0?.count, 2)
        XCTAssertEqual(uploadedEvents0?[0].eventType, "testEvent-0")
        XCTAssertEqual(uploadedEvents0?[1].eventType, "testEvent-1")

        let uploadedEvents1 = BaseEvent.fromArrayString(jsonString: httpClient.uploadedEvents[1])
        XCTAssertEqual(uploadedEvents1?.count, 1)
        XCTAssertEqual(uploadedEvents1?[0].eventType, "testEvent-1")
    }
}
