//
//  EventPipelineTests.swift
//
//
//  Created by Marvin Liu on 11/30/22.
//

import XCTest

@testable import Amplitude_Swift

final class EventPipelineTests: XCTestCase {
    private static let FLUSH_INTERVAL_SECONDS = 1.0
    private static let IDENTIFY_UPLOAD_INTERVAL_SECONDS = 1.5

    private var configuration: Configuration!
    private var amplitude: Amplitude!
    private var eventPipeline: EventPipeline!
    private var storage: FakeInMemoryStorage!
    private var httpClient: FakeHttpClient!

    override func setUp() {
        super.setUp()
        storage = FakeInMemoryStorage()
        configuration = Configuration(
            apiKey: "testApiKey",
            flushIntervalMillis: Int(Self.FLUSH_INTERVAL_SECONDS * 1000),
            storageProvider: storage,
            identifyUploadIntervalMillis: Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        )
        amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration)
        eventPipeline = EventPipeline(amplitude: amplitude, minIdentifyUploadInterval: Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000))
        eventPipeline.httpClient = httpClient
    }

    func testInit() {
        XCTAssertEqual(eventPipeline.amplitude.configuration.apiKey, amplitude.configuration.apiKey)
    }

    func testPutEvent() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")

        let eventExpectation = expectation(description: "Async function")
        eventPipeline.put(event: testEvent) {
            eventExpectation.fulfill()
        }
        XCTAssertEqual(testEvent.attempts, 1)

        let waitResult = XCTWaiter.wait(for: [eventExpectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
    }

    func testFlush() {
        let testEvent = BaseEvent(userId: "unit-test", deviceId: "unit-test-machine", eventType: "testEvent")
        try? eventPipeline.storage?.write(key: StorageKey.EVENTS, value: testEvent)

        let flushExpectation = expectation(description: "Async function")
        eventPipeline.flush {
            flushExpectation.fulfill()
        }
        let waitResult = XCTWaiter.wait(for: [flushExpectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["testEvent"])
    }

    func testPutIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))
    }

    func testPutIdentifyEventsWithDisabledIdentifyBatching() {
        amplitude.configuration.disableIdentifyBatching = true
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testPutIncompatibleIdentifyEvents() {
        let testEvent1 = BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-2", eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testPutSomeEventAfterIdentifyEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "someEvent")

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testPutIdentifyEventAndFlush() {
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "someEvent")
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let flushExpectation = expectation(description: "Async function")
        eventPipeline.flush {
            flushExpectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [flushExpectation, upload1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["someEvent", "$identify"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testPutIdentifyEventAndWaitForUploadInterval() {
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        waitResult = XCTWaiter.wait(for: [upload1Expectation], timeout: Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 0.5)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["$identify"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testPutIdentifyEventsAndWaitForUploadInterval() {
        let upload1Expectation = expectation(description: "upload1")
        let upload2Expectation = expectation(description: "upload2")
        httpClient.uploadExpectations = [upload1Expectation, upload2Expectation]

        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        waitResult = XCTWaiter.wait(for: [upload1Expectation], timeout: Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 0.5)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["$identify"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))

        waitResult = XCTWaiter.wait(for: [upload2Expectation], timeout: Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 0.5)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 2)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[1]), ["$identify"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testIdentifyEventAndWaitForFlushInterval() {
        configuration.identifyUploadIntervalMillis = 10000
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        waitResult = XCTWaiter.wait(for: [upload1Expectation], timeout: Self.FLUSH_INTERVAL_SECONDS + 0.5)
        XCTAssertEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testPutSomeEventAndIdentifyEventAndWaitForFlushInterval() {
        configuration.identifyUploadIntervalMillis = 10000
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "someEvent")
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 1)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        waitResult = XCTWaiter.wait(for: [upload1Expectation], timeout: Self.FLUSH_INTERVAL_SECONDS + 0.5)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["someEvent"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testPutSomeEventsAndIdentifyEventAndWaitForFlushInterval() {
        configuration.identifyUploadIntervalMillis = 10000
        configuration.flushQueueSize = 3
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "someEvent1")
        let testEvent2 = BaseEvent(eventType: "someEvent2")
        let testEvent3 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation, event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let event3Expectation = expectation(description: "event3")
        eventPipeline.put(event: testEvent3) {
            event3Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event3Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        waitResult = XCTWaiter.wait(for: [upload1Expectation], timeout: Self.FLUSH_INTERVAL_SECONDS - 0.5)
        XCTAssertEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 0)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testPutSomeEventsAndIdentifyEventAndWaitForFlushIntervalWithDisabledEntityBatching() {
        configuration.disableIdentifyBatching = true
        configuration.identifyUploadIntervalMillis = 10000
        configuration.flushQueueSize = 3
        let upload1Expectation = expectation(description: "upload")
        httpClient.uploadExpectations = [upload1Expectation]

        let testEvent1 = BaseEvent(eventType: "someEvent1")
        let testEvent2 = BaseEvent(eventType: "someEvent2")
        let testEvent3 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        let event1Expectation = expectation(description: "event1")
        eventPipeline.put(event: testEvent1) {
            event1Expectation.fulfill()
        }

        let event2Expectation = expectation(description: "event2")
        eventPipeline.put(event: testEvent2) {
            event2Expectation.fulfill()
        }

        var waitResult = XCTWaiter.wait(for: [event1Expectation, event2Expectation], timeout: 1)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(eventPipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let event3Expectation = expectation(description: "event3")
        eventPipeline.put(event: testEvent3) {
            event3Expectation.fulfill()
        }

        waitResult = XCTWaiter.wait(for: [event3Expectation, upload1Expectation], timeout: Self.FLUSH_INTERVAL_SECONDS - 0.5)
        XCTAssertNotEqual(waitResult, .timedOut)
        XCTAssertEqual(httpClient.uploadCount, 1)
        XCTAssertEqual(extractEntityTypes(httpClient.uploadedEvents[0]), ["someEvent1", "someEvent2", "$identify"])
        XCTAssertEqual(eventPipeline.eventCount, 0)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    private func extractEntityTypes(_ eventsString: String) -> [String] {
        var result = [String]()

        guard let regex = try? NSRegularExpression(pattern: #"\"event_type"\s*:\s*"([^"]*)""#) else {
            return result
        }

        let eventsNSString = NSString(string: eventsString)
        regex.matches(in: eventsString, options: [], range: NSRange(location: 0, length: eventsNSString.length)).forEach
        { match in
            (1..<match.numberOfRanges).forEach {
                if match.range(at: $0).location != NSNotFound {
                    let eventType = eventsNSString.substring(with: match.range(at: $0))
                    result.append(eventType)
                }
            }
        }
        return result
    }
}
