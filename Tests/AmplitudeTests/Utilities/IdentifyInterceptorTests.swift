import XCTest

@testable import Amplitude_Swift

final class IdentifyInterceptorTests: XCTestCase {
    private static let IDENTIFY_UPLOAD_INTERVAL_SECONDS = 1.5

    private var storage: FakeInMemoryStorage!
    private var identifyStorage: FakeInMemoryStorage!
    private var httpClient: FakeHttpClient!
    private var interceptor: TestIdentifyInterceptor!
    private var configuration: Configuration!
    private var pipeline: EventPipeline!

    override func setUp() {
        super.setUp()
        storage = FakeInMemoryStorage()
        identifyStorage = FakeInMemoryStorage()
        let identifyBatchIntervalMillis = Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        configuration = Configuration(
            apiKey: "testApiKey",
            storageProvider: storage,
            identifyStorageProvider: identifyStorage,
            identifyBatchIntervalMillis: identifyBatchIntervalMillis
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        interceptor = TestIdentifyInterceptor(
            configuration: configuration,
            pipeline: pipeline
        )
        interceptor.setIdentifyBatchInterval(identifyBatchIntervalMillis)
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }

    func testMinimumIdentifyBatchInterval() {
        var identifyBatchIntervalMillis = 0
        var interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS - 1
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(identifyBatchIntervalMillis))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS * 2
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(identifyBatchIntervalMillis))
    }

    func testIsInterceptEvent() {
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(userId: "user-1", eventType: "testEvent"))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(userId: "user-1", eventType: "$groupidentify"))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(userId: "user-1", eventType: "$identify"))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", groups: [String: Any?]()))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", groups: ["key-1": "value-1"]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: [String: Any?]()))
        )
        XCTAssertTrue(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-", "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isInterceptEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-", "$add": [String: Any?]()]))
        )
    }

    func testMergeUserProperties() {
        var merged = interceptor.mergeUserProperties(destination: nil, source: nil)
        XCTAssertTrue(getDictionary(merged).isEqual(to: [:]))

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": "value-1"],
            source: [:]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(to: ["key-1": "value-1"]))

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": "value-1"],
            source: ["key-2": "value-2"]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["key-1": "value-1", "key-2": "value-2"])
        )

        merged = interceptor.mergeUserProperties(
            destination: nil,
            source: ["key-2": "value-2"]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(to: ["key-2": "value-2"]))

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": "value-1-1", "key-2": "value-2"],
            source: ["key-3": "value-3", "key-1": "value-1-2"]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": nil, "key-2": "value-2", "key-3": nil, "key-4": nil],
            source: ["key-1": "value-1", "key-2": nil, "key-3": nil, "key-5": nil]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["key-1": "value-1", "key-2": "value-2", "key-3": nil, "key-4": nil, "key-5": nil])
        )

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": NSNull(), "key-2": "value-2", "key-3": NSNull(), "key-4": NSNull()],
            source: ["key-1": "value-1", "key-2": NSNull(), "key-3": NSNull(), "key-5": NSNull()]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["key-1": "value-1", "key-2": "value-2", "key-3": NSNull(), "key-4": NSNull(), "key-5": NSNull()])
        )
    }

    func testMergeUserPropertyOperations() {
        var merged = interceptor.mergeUserPropertiesOperations(destination: nil, source: nil)
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["$set": [:]])
        )

        merged = interceptor.mergeUserPropertiesOperations(
            destination: ["$set": ["key-1": "value-1"]],
            source: ["$set": [:]]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(to: ["$set": ["key-1": "value-1"]]))

        merged = interceptor.mergeUserPropertiesOperations(
            destination: ["$set": ["key-1": "value-1"]],
            source: ["$set": ["key-2": "value-2"]]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["$set": ["key-1": "value-1", "key-2": "value-2"]])
        )

        merged = interceptor.mergeUserPropertiesOperations(
            destination: nil,
            source: ["$set": ["key-2": "value-2"]]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["$set": ["key-2": "value-2"]])
        )

        merged = interceptor.mergeUserPropertiesOperations(
            destination: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]],
            source: ["$set": ["key-3": "value-3", "key-1": "value-1-2"]]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]])
        )

        merged = interceptor.mergeUserPropertiesOperations(
            destination: ["$set": ["key-1": "value-1-1", "key-2": "value-2"], "$add": ["add-1": "add-2"]],
            source: ["$set": ["key-3": "value-3", "key-1": "value-1-2"]]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])
        )
    }

    func testInterceptIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var events = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        // second $set only event should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        events = identifyStorage.events()
        XCTAssertNil(e2)
        XCTAssertEqual(events.count, 2)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertNotNil(events[1].userProperties)
        XCTAssertTrue(getDictionary(events[1].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptedIdentifysSentOnUserIdChange() {
        let testEvent1 = BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-2", eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // $set only event with user1 should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var events = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        // $set only event with user2 should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNil(e2)

        // previous intercept with user1 should be transfered to event storage
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptTransferIdentifyEventsOnNonInterceptOperation() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))

        // identify with $add should receive merged user properties
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2!.eventType, "$identify")
        XCTAssertNotNil(e2!.userProperties)
        XCTAssertTrue(getDictionary(e2!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
        events = storage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyAndStandardEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "someEvent", userProperties: ["key-1": "value-1-2", "key-3": "value-3"])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var events = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))

        // standard event should be modified to include intercepted user properties, flattened
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2!.eventType, "someEvent")
        XCTAssertNotNil(e2!.userProperties)
        XCTAssertTrue(getDictionary(e2!.userProperties!).isEqual(to: ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
        events = storage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifySentOnUserIdChange() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-1", eventType: "someEvent")

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var events = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        // standard event should be returned unmodified
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2?.eventType, "someEvent")
        XCTAssertNil(e2?.userProperties)

        // intercept storage should be cleared
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)

        // Identify for previous userId should be transfered to event storage
        events = storage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "$identify")
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testInterceptIdentifyAndIdentifyClearEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        // clear-all should return clear-all event, clear intercept storage
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2?.eventType, "$identify")
        XCTAssertNotNil(e2?.userProperties)
        XCTAssertTrue(getDictionary((e2?.userProperties)!).isEqual(to: ["$clearAll": "-"]))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyEventIsTransferedOnUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        // intercepted event should be transfered on batch interval
        let dummyExpectation = expectation(description: "dummy")
        _ = XCTWaiter.wait(for: [dummyExpectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
    }

    func testMultipleInterceptIdentifyEventsAreTransferedOnUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let dummy1Expectation = expectation(description: "dummy1")
        _ = XCTWaiter.wait(for: [dummy1Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 1)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)

        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // set only should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNil(e2)
        XCTAssertEqual(pipeline.eventCount, 1)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(events[0].userProperties)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))

        let dummy2Expectation = expectation(description: "dummy2")
        _ = XCTWaiter.wait(for: [dummy2Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 2)
        events = identifyStorage.events()
        XCTAssertEqual(events.count, 0)
    }

    func testInterceptIdentifyEventsWithNilValueOverrides() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": nil, "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1", "key-3": "value-3", "key-4": nil]])
        let testEvent3 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": nil, "key-2": nil, "key-3": nil]])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var events = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(getDictionary(events[0].userProperties!).isEqual(to: ["$set": ["key-1": nil, "key-2": "value-2"]]))

        // second $set only event should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        events = identifyStorage.events()
        XCTAssertNil(e2)
        XCTAssertEqual(events.count, 2)
        XCTAssertNotNil(events[1].userProperties)
        XCTAssertTrue(getDictionary(events[1].userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-3": "value-3", "key-4": nil]]))

        // third $set only event should be intercepted
        let e3 = interceptor.intercept(event: testEvent3)
        events = identifyStorage.events()
        XCTAssertNil(e3)
        XCTAssertEqual(events.count, 3)
        XCTAssertNotNil(events[2].userProperties)
        XCTAssertTrue(getDictionary(events[2].userProperties!).isEqual(to: ["$set": ["key-1": nil, "key-2": nil, "key-3": nil]]))

        // intercepted event should not contain nil values
        let e = interceptor.getCombinedInterceptedIdentify()
        XCTAssertNotNil(e)
        XCTAssertNotNil(e!.userProperties)
        XCTAssertTrue(getDictionary(e!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2", "key-3": "value-3"]]))
    }
}
