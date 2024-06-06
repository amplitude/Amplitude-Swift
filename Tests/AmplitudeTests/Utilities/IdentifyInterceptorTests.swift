import XCTest

@testable import AmplitudeSwift

final class IdentifyInterceptorTests: XCTestCase {
    private static let IDENTIFY_UPLOAD_INTERVAL_SECONDS = 1.5

    private var storage: FakeInMemoryStorage!
    private var identifyStorage: FakeInMemoryStorage!
    private var httpClient: FakeHttpClient!
    private var interceptor: TestIdentifyInterceptor!
    private var configuration: Configuration!
    private var pipeline: EventPipeline!
    private var mockPathCreation: MockPathCreation!
    private var amplitude: Amplitude!

    override func setUp() {
        super.setUp()
        storage = FakeInMemoryStorage()
        identifyStorage = FakeInMemoryStorage()
        let identifyBatchIntervalMillis = Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        configuration = Configuration(
            apiKey: "testApiKey",
            storageProvider: storage,
            identifyStorageProvider: identifyStorage,
            identifyBatchIntervalMillis: identifyBatchIntervalMillis,
            offline: NetworkConnectivityCheckerPlugin.Disabled
        )
        amplitude = Amplitude(configuration: configuration)
        mockPathCreation = MockPathCreation()
        amplitude.add(plugin: NetworkConnectivityCheckerPlugin(pathCreation: mockPathCreation))
        httpClient = FakeHttpClient(configuration: configuration, diagnostics: configuration.diagonostics)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        interceptor = TestIdentifyInterceptor(
            configuration: configuration,
            pipeline: pipeline,
            queue: amplitude.trackingQueue
        )
        interceptor.setIdentifyBatchInterval(identifyBatchIntervalMillis)
    }

    func getDictionary(_ props: [String: Any?]) -> NSDictionary {
        return NSDictionary(dictionary: props as [AnyHashable: Any])
    }

    func testMinimumIdentifyBatchInterval() {
        var identifyBatchIntervalMillis = 0
        var interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, queue: .main, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS - 1
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, queue: .main, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, queue: .main, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
        XCTAssertEqual(interceptor1.getIdentifyBatchInterval(), TimeInterval.milliseconds(identifyBatchIntervalMillis))

        identifyBatchIntervalMillis = Constants.MIN_IDENTIFY_BATCH_INTERVAL_MILLIS * 2
        interceptor1 = IdentifyInterceptor(configuration: configuration, pipeline: pipeline, queue: .main, identifyBatchIntervalMillis: identifyBatchIntervalMillis)
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
        XCTAssertEqual(getDictionary(merged),
                       ["key-1": "value-1", "key-2": "value-2", "key-3": nil, "key-4": nil, "key-5": nil] as NSDictionary)

        merged = interceptor.mergeUserProperties(
            destination: ["key-1": NSNull(), "key-2": "value-2", "key-3": NSNull(), "key-4": NSNull()],
            source: ["key-1": "value-1", "key-2": NSNull(), "key-3": NSNull(), "key-5": NSNull()]
        )
        XCTAssertTrue(getDictionary(merged).isEqual(
            to: ["key-1": "value-1", "key-2": "value-2", "key-3": NSNull(), "key-4": NSNull(), "key-5": NSNull()])
        )
    }

    func testInterceptIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // second $set only event should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e2)
        XCTAssertEqual(interceptedIdentifies.count, 2)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(interceptedIdentifies[1].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[1].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[1].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
        XCTAssertEqual(storage.events().count, 0)
    }

    func testInterceptedIdentifysSentOnUserIdChange() {
        let testEvent1 = BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-2", eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // $set only event with user1 should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // $set only event with user2 should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNil(e2)

        // previous intercept with user1 should be transferred to event storage
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptTransferIdentifyEventsOnNonInterceptOperation() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))
        XCTAssertEqual(storage.events().count, 0)

        // event with $add should not be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2!.eventType, "$identify")
        XCTAssertNotNil(e2!.userProperties)
        XCTAssertTrue(getDictionary(e2!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-3": "value-3"], "$add": ["add-1": "add-2"]]))

        // intercept should be transferred to event storage
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))
    }

    func testInterceptIdentifyAndStandardEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3-1"]])
        let testEvent3 = BaseEvent(eventType: "someEvent", userProperties: ["key-1": "value-1-3", "key-3": "value-3-2"])

        // $set only event should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))
        XCTAssertEqual(storage.events().count, 0)

        // second $set only event should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e2)
        XCTAssertEqual(interceptedIdentifies.count, 2)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]))
        XCTAssertEqual(interceptedIdentifies[1].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[1].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[1].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-3": "value-3-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // standard event should not be intercepted
        let e3 = interceptor.intercept(event: testEvent3)
        XCTAssertNotNil(e3)
        XCTAssertEqual(e3!.eventType, "someEvent")
        XCTAssertNotNil(e3!.userProperties)
        // standard event should contain only own userProperties
        XCTAssertTrue(getDictionary(e3!.userProperties!).isEqual(to: ["key-1": "value-1-3", "key-3": "value-3-2"]))

        // intercepted identify should be transferred to event storage
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        // intercepted identify should contain collapsed properties, not including properties of standard event
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3-1"]]))
    }

    func testInterceptIdentifySentOnUserIdChange() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-1", eventType: "someEvent")

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertNil(e1)
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // standard event should be returned unmodified
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2?.eventType, "someEvent")
        XCTAssertNil(e2?.userProperties)

        // intercept storage should be cleared
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)

        // Identify for previous userId should be transferred to event storage
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testInterceptIdentifyAndIdentifyClearEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // clear-all should return clear-all event, clear intercept storage
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNotNil(e2)
        XCTAssertEqual(e2?.eventType, "$identify")
        XCTAssertNotNil(e2?.userProperties)
        XCTAssertTrue(getDictionary((e2?.userProperties)!).isEqual(to: ["$clearAll": "-"]))
        // intercept identifies should be cleared
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        XCTAssertEqual(storage.events().count, 0)
    }

    func testInterceptIdentifyEventIsTransferredOnUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // intercepted event should be transferred on batch interval
        let dummyExpectation = expectation(description: "dummy")
        _ = XCTWaiter.wait(for: [dummyExpectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        let standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
    }

    func testMultipleInterceptIdentifyEventsAreTransferredOnUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        // set only should be intercepted
        let e1 = interceptor.intercept(event: testEvent1)
        XCTAssertNil(e1)
        XCTAssertEqual(pipeline.eventCount, 0)
        var interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))
        XCTAssertEqual(storage.events().count, 0)

        // intercepted event should be transferred on batch interval
        let dummy1Expectation = expectation(description: "dummy1")
        _ = XCTWaiter.wait(for: [dummy1Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(pipeline.eventCount, 1)
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        var standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 1)
        XCTAssertEqual(standardEvents[0].eventType, "$identify")
        XCTAssertNotNil(standardEvents[0].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[0].userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        // set only should be intercepted
        let e2 = interceptor.intercept(event: testEvent2)
        XCTAssertNil(e2)
        XCTAssertEqual(pipeline.eventCount, 1)
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 1)
        XCTAssertEqual(interceptedIdentifies[0].eventType, "$identify")
        XCTAssertNotNil(interceptedIdentifies[0].userProperties)
        XCTAssertTrue(getDictionary(interceptedIdentifies[0].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))

        // intercepted event should be transferred on batch interval
        let dummy2Expectation = expectation(description: "dummy2")
        _ = XCTWaiter.wait(for: [dummy2Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        amplitude.waitForTrackingQueue()
        XCTAssertEqual(pipeline.eventCount, 2)
        interceptedIdentifies = identifyStorage.events()
        XCTAssertEqual(interceptedIdentifies.count, 0)
        standardEvents = storage.events()
        XCTAssertEqual(standardEvents.count, 2)
        XCTAssertEqual(standardEvents[1].eventType, "$identify")
        XCTAssertNotNil(standardEvents[1].userProperties)
        XCTAssertTrue(getDictionary(standardEvents[1].userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
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
