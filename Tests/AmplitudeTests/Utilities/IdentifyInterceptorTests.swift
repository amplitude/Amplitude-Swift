import XCTest

@testable import Amplitude_Swift

final class IdentifyInterceptorTests: XCTestCase {
    private static let IDENTIFY_UPLOAD_INTERVAL_SECONDS = 1.5

    private var storage: FakeInMemoryStorage!
    private var identifyStorage: FakeInMemoryStorage!
    private var httpClient: FakeHttpClient!
    private var interceptor: IdentifyInterceptor!
    private var configuration: Configuration!
    private var pipeline: EventPipeline!

    override func setUp() {
        super.setUp()
        storage = FakeInMemoryStorage()
        identifyStorage = FakeInMemoryStorage()
        configuration = Configuration(
            apiKey: "testApiKey",
            storageProvider: storage,
            identifyStorageProvider: identifyStorage,
            identifyBatchIntervalMillis: Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        interceptor = IdentifyInterceptor(
            configuration: configuration,
            pipeline: pipeline,
            minIdentifyBatchInterval: Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        )
    }

    func testIsAllowedMergeSource() {
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(userId: "user-1", eventType: "testEvent"))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(userId: "user-1", eventType: "$groupidentify"))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(userId: "user-1", eventType: "$identify"))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", groups: [String: Any?]()))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", groups: ["key-1": "value-1"]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: [String: Any?]()))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-", "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-", "$add": [String: Any?]()]))
        )
    }

    func testMergeUserProperties() {
        var merged = interceptor.mergeUserProperties(destination: nil, source: nil)
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": [:]])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["$set": ["key-1": "value-1"]],
            source: ["$set": [:]]
        )
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": ["key-1": "value-1"]])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["$set": ["key-1": "value-1"]],
            source: ["$set": ["key-2": "value-2"]]
        )
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": ["key-1": "value-1", "key-2": "value-2"]])
        )

        merged = interceptor.mergeUserProperties(
            destination: nil,
            source: ["$set": ["key-2": "value-2"]]
        )
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": ["key-2": "value-2"]])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]],
            source: ["$set": ["key-3": "value-3", "key-1": "value-1-2"]]
        )
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["$set": ["key-1": "value-1-1", "key-2": "value-2"], "$add": ["add-1": "add-2"]],
            source: ["$set": ["key-3": "value-3", "key-1": "value-1-2"]]
        )
        XCTAssertTrue(NSDictionary(dictionary: merged).isEqual(
            to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])
        )
    }

    func testInterceptIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 0)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertNotNil(events[1].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[1].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptIncompatibleIdentifyEvents() {
        let testEvent1 = BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-2", eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptTransferIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyAndSomeEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "someEvent", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "someEvent")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyAndSomeClearEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "someEvent", userProperties: ["$clearAll": "-"])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "someEvent")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$clearAll": "-"]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyAndSomeIncompatibleEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-1", eventType: "someEvent")

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 2)
        events = storage.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(events[1].eventType, "someEvent")
        XCTAssertNil(events[1].userProperties)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyAndIdentifyClearEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 0)
        events = storage.events()
        XCTAssertEqual(events.count, 0)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyEventAndWaitForUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let dummyExpectation = expectation(description: "dummy")
        _ = XCTWaiter.wait(for: [dummyExpectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyEventsAndWaitForUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let dummy1Expectation = expectation(description: "dummy1")
        _ = XCTWaiter.wait(for: [dummy1Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 1)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)

        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(NSDictionary(dictionary: events[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))

        let dummy2Expectation = expectation(description: "dummy2")
        _ = XCTWaiter.wait(for: [dummy2Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 2)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }
}
