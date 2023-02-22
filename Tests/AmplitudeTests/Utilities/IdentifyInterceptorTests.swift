import XCTest

@testable import Amplitude_Swift

final class IdentifyInterceptorTests: XCTestCase {
    private static let IDENTIFY_UPLOAD_INTERVAL_SECONDS = 1.5

    private var storage: FakeInMemoryStorage!
    private var httpClient: FakeHttpClient!
    private var interceptor: IdentifyInterceptor!
    private var configuration: Configuration!
    private var pipeline: EventPipeline!

    override func setUp() {
        super.setUp()
        storage = FakeInMemoryStorage()
        configuration = Configuration(
            apiKey: "testApiKey",
            storageProvider: storage,
            identifyBatchIntervalMillis: Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS * 1000)
        )
        let amplitude = Amplitude(configuration: configuration)
        httpClient = FakeHttpClient(configuration: configuration)
        pipeline = EventPipeline(amplitude: amplitude)
        pipeline.httpClient = httpClient
        interceptor = IdentifyInterceptor(
            configuration: configuration,
            pipeline: pipeline,
            logger: nil,
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
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(userId: "user-1", eventType: "$identify"))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", groups: [String: Any?]()))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", groups: ["key-1": "value-1"]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: [String: Any?]()))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeSource(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"]))
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

    func testIsAllowedMergeDestination() {
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(userId: "user-1", eventType: "testEvent"))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(userId: "user-1", eventType: "$groupidentify"))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(userId: "user-1", eventType: "$identify"))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "$identify", groups: [String: Any?]()))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "testEvent", groups: ["key-1": "value-1"]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "$identify", userProperties: [String: Any?]()))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "testEvent", userProperties: ["$set": [String: Any?]()]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]))
        )
        XCTAssertTrue(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "testEvent", userProperties: ["$set": [String: Any?](), "$clearAll": "-"]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "$identify", userProperties: ["$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "testEvent", userProperties: ["$set": [String: Any?](), "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-", "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.isAllowedMergeDestination(BaseEvent(eventType: "testEvent", userProperties: ["$set": [String: Any?](), "$clearAll": "-", "$add": [String: Any?]()]))
        )
    }

    func testCanMergeEvents() {
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", eventType: "$identify"),
                source: BaseEvent(userId: "user-1", eventType: "$identify")
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(deviceId: "device-1", eventType: "$identify"),
                source: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                source: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", eventType: "$identify"),
                source: BaseEvent(eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify"),
                source: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", eventType: "$identify"),
                source: BaseEvent(userId: "user-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(deviceId: "device-1", eventType: "$identify"),
                source: BaseEvent(deviceId: "device-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                source: BaseEvent(userId: "user-1", deviceId: "device-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                source: BaseEvent(userId: "user-2", deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(userId: "user-1", eventType: "$identify"),
                source: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                source: BaseEvent(eventType: "$identify", userProperties: [String: Any?]())
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify"),
                source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
                source: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "someEvent"),
                source: BaseEvent(eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "$identify"),
                source: BaseEvent(eventType: "someEvent")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeEvents(
                destination: BaseEvent(eventType: "someEvent"),
                source: BaseEvent(eventType: "someEvent")
            )
        )
    }

    func testMergeIdentifyEvents() {
        var mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(userId: "user-1", eventType: "$identify"),
            source: BaseEvent(userId: "user-1", eventType: "$identify")
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertEqual(mergedEvent!.userId, "user-1")
        XCTAssertNil(mergedEvent!.userProperties)

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(deviceId: "device-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]]),
            source: BaseEvent(deviceId: "device-1", eventType: "$identify")
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertEqual(mergedEvent!.deviceId, "device-1")
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$clearAll": "-"]))

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$clearAll": "-"]))

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        )
        XCTAssertNil(mergedEvent)

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]]))

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify"),
            source: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1", "key-2": "value-2"]])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNil(mergedEvent)

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            source: BaseEvent(eventType: "someEvent", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )

        mergedEvent = interceptor.mergeEvents(
            destination: BaseEvent(eventType: "someEvent", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            source: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]]))
    }

    func testInterceptIdentifyEvents() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))
    }

    func testInterceptIncompatibleIdentifyEvents() {
        let testEvent1 = BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-2", eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))
    }

    func testInterceptIdentifyAndSomeEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(eventType: "someEvent")

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testInterceptIdentifyAndSomeIncompatibleEvent() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        let testEvent2 = BaseEvent(userId: "user-1", eventType: "someEvent")

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testInterceptIdentifyEventAndWaitForUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let dummyExpectation = expectation(description: "dummy")
        _ = XCTWaiter.wait(for: [dummyExpectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }

    func testInterceptIdentifyEventsAndWaitForUploadInterval() {
        let testEvent1 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])

        interceptor.intercept(event: testEvent1)
        XCTAssertEqual(pipeline.eventCount, 0)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        let dummy1Expectation = expectation(description: "dummy1")
        _ = XCTWaiter.wait(for: [dummy1Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 1)
        XCTAssertNil(storage.interceptedIdentifyEvent)

        let testEvent2 = BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-2": "value-2"]])

        interceptor.intercept(event: testEvent2)
        XCTAssertEqual(pipeline.eventCount, 1)
        XCTAssertNotNil(storage.interceptedIdentifyEvent)
        XCTAssertNotNil(storage.interceptedIdentifyEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: storage.interceptedIdentifyEvent!.userProperties!).isEqual(to: ["$set": ["key-2": "value-2"]]))

        let dummy2Expectation = expectation(description: "dummy2")
        _ = XCTWaiter.wait(for: [dummy2Expectation], timeout: TimeInterval.seconds(Int(Self.IDENTIFY_UPLOAD_INTERVAL_SECONDS + 1)))
        XCTAssertEqual(pipeline.eventCount, 2)
        XCTAssertNil(storage.interceptedIdentifyEvent)
    }
}
