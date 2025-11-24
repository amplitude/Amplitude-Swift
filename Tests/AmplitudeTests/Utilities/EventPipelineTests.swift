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
            diagonostics: Diagnostics(),
            diagnosticsClient: FakeDiagnosticsClient())
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
        XCTAssertEqual(pipeline.configuration.apiKey, configuration.apiKey)
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
        pipeline.configuration.offline = false

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(pipeline.configuration.offline, false)

        pipeline.configuration.offline = true
        pipeline.flush()

        XCTAssertEqual(pipeline.configuration.offline, true)
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

    func testOneUploadAtATime() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)
        pipeline?.storage?.rollover()

        let testEvent2 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent2")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent2)
        pipeline.storage?.rollover()

        let httpResponseExpectation1 = expectation(description: "httpresponse1")
        let httpResponseExpectation2 = expectation(description: "httpresponse2")
        httpClient.uploadExpectations = [httpResponseExpectation1, httpResponseExpectation2]

        httpResponseExpectation2.isInverted = true

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }

        wait(for: [httpResponseExpectation1], timeout: 1)

        httpResponseExpectation2.isInverted = false

        wait(for: [httpResponseExpectation2, flushExpectation], timeout: 1)

        XCTAssertEqual(httpClient.uploadCount, 2)
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

    // test continues to fail until the event is uploaded
    func testContinuousFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 2

        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let uploadExpectations = (0..<4).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        httpClient.uploadResults = [
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // instant failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +1s failure
            .failure(NSError(domain: "unknown", code: 0, userInfo: nil)), // +2s failure, go offline
            .success(200)
        ]

        pipeline.flush()
        wait(for: [uploadExpectations[0], uploadExpectations[1]], timeout: 2)

        XCTAssertEqual(httpClient.uploadCount, 2)
        XCTAssertEqual(pipeline.configuration.offline, false)

        wait(for: [uploadExpectations[2]], timeout: 3)

        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, true)

        pipeline.configuration.offline = false
        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }
        wait(for: [uploadExpectations[3], flushExpectation], timeout: 1)

        XCTAssertEqual(httpClient.uploadCount, 4)
    }

    func testContinuesHandledFailure() {
        pipeline.configuration.offline = false
        pipeline.configuration.flushMaxRetries = 1

        let testEvent1 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent1)
        pipeline.storage?.rollover()

        let testEvent2 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent2)
        pipeline.storage?.rollover()

        let testEvent3 = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? pipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent3)
        pipeline.storage?.rollover()

        let uploadExpectations = (0..<3).map { i in expectation(description: "httpresponse-\(i)") }
        httpClient.uploadExpectations = uploadExpectations

        let invalidResponseData = "{\"events_with_invalid_fields\": {\"user_id\": [0]}}".data(using: .utf8)!
        httpClient.uploadResults = [
            .failure(HttpClient.Exception.httpError(code: HttpClient.HttpStatus.BAD_REQUEST.rawValue, data: invalidResponseData)),
            .failure(HttpClient.Exception.httpError(code: HttpClient.HttpStatus.PAYLOAD_TOO_LARGE.rawValue, data: nil)),
            .success(200),
        ]

        let flushExpectation = expectation(description: "flush")
        pipeline.flush {
            flushExpectation.fulfill()
        }

        wait(for: uploadExpectations + [flushExpectation], timeout: 1)
        XCTAssertEqual(httpClient.uploadCount, 3)
        XCTAssertEqual(pipeline.configuration.offline, false)
    }
}
