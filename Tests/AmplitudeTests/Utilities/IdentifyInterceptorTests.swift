import XCTest

@testable import Amplitude_Swift

final class IdentifyInterceptorTests: XCTestCase {
    private var interceptor: IdentifyInterceptor!

    override func setUp() {
        super.setUp()
        interceptor = IdentifyInterceptor()
    }

    func testCanMergeIdentifyEvent() {
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(userId: "user-1", eventType: "testEvent"))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(userId: "user-1", eventType: "$identify"))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", groups: [String: Any?]()))
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", groups: ["key-1": "value-1"]))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: [String: Any?]()))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]))
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"]))
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-", "$add": [String: Any?]()]))
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvent(BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-", "$add": [String: Any?]()]))
        )
    }

    func testCanMergeIdentifyEvents() {
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", eventType: "$identify"),
                event2: BaseEvent(userId: "user-1", eventType: "$identify")
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(deviceId: "device-1", eventType: "$identify"),
                event2: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                event2: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify")
            )
        )

        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", eventType: "$identify"),
                event2: BaseEvent(eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify"),
                event2: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", eventType: "$identify"),
                event2: BaseEvent(userId: "user-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(deviceId: "device-1", eventType: "$identify"),
                event2: BaseEvent(deviceId: "device-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                event2: BaseEvent(userId: "user-1", deviceId: "device-2", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", deviceId: "device-1", eventType: "$identify"),
                event2: BaseEvent(userId: "user-2", deviceId: "device-1", eventType: "$identify")
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(userId: "user-1", eventType: "$identify"),
                event2: BaseEvent(deviceId: "device-1", eventType: "$identify")
            )
        )

        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                event2: BaseEvent(eventType: "$identify", userProperties: [String: Any?]())
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify"),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?](), "$clearAll": "-"])
            )
        )
        XCTAssertTrue(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
            )
        )
        XCTAssertFalse(
            interceptor.canMergeIdentifyEvents(
                event1: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
                event2: BaseEvent(eventType: "$identify", userProperties: ["$set": [String: Any?]()])
            )
        )
    }

    func testMergeIdentifyEvents() {
        var mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(userId: "user-1", eventType: "$identify"),
            event2: BaseEvent(userId: "user-1", eventType: "$identify")
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertEqual(mergedEvent!.userId, "user-1")
        XCTAssertNil(mergedEvent!.userProperties)

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(deviceId: "device-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]]),
            event2: BaseEvent(deviceId: "device-1", eventType: "$identify")
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertEqual(mergedEvent!.deviceId, "device-1")
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1"]]))

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$clearAll": "-"]))

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]]),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$clearAll": "-"]))

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify", userProperties: ["$clearAll": "-"]),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1"]])
        )
        XCTAssertNil(mergedEvent)

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1-2", "key-2": "value-2", "key-3": "value-3"]]))

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify"),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1", "key-2": "value-2"]])
        )
        XCTAssertNotNil(mergedEvent)
        XCTAssertNotNil(mergedEvent!.userProperties)
        XCTAssertTrue(NSDictionary(dictionary: mergedEvent!.userProperties!).isEqual(to: ["$set": ["key-1": "value-1", "key-2": "value-2"]]))

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(userId: "user-1", eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            event2: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNil(mergedEvent)

        mergedEvent = interceptor.mergeIdentifyEvents(
            event1: BaseEvent(eventType: "$identify", userProperties: ["$set": ["key-1": "value-1-1", "key-2": "value-2"]]),
            event2: BaseEvent(eventType: "someEvent", userProperties: ["$set": ["key-1": "value-1-2", "key-3": "value-3"]])
        )
        XCTAssertNil(mergedEvent)
    }
}
