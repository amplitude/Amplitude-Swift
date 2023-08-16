//
//  BaseEventTests.swift
//
//
//  Created by Marvin Liu on 11/23/22.
//

import XCTest

@testable import AmplitudeSwift

// swiftlint:disable force_cast
final class BaseEventTests: XCTestCase {
    func testToString() throws {
        let baseEvent = BaseEvent(
            plan: Plan(
                branch: "test-branch",
                source: "test-source",
                version: "test-version",
                versionId: "test-version-id"
            ),
            ingestionMetadata: IngestionMetadata(
                sourceName: "test-source-name",
                sourceVersion: "test-source-version"
            ),
            eventType: "test",
            eventProperties: [
                "integer": 1,
                "string": "stringValue",
                "array": [1, 2, 3],
            ]
        )

        let baseEventData = baseEvent.toString().data(using: .utf8)!
        let baseEventDict =
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: baseEventData, options: .mutableContainers) as? [String: AnyObject]
            )
        let baseEventProperties = try XCTUnwrap(baseEventDict["event_properties"] as? [String: AnyObject])
        let baseEventPlan = try XCTUnwrap(baseEventDict["plan"] as? [String: String])
        let baseEventIngestionMetadata = try XCTUnwrap(baseEventDict["ingestion_metadata"] as? [String: String])
        XCTAssertEqual(
            baseEventDict["event_type"] as! String,
            "test"
        )
        XCTAssertEqual(
            baseEventProperties["integer"] as! Int,
            1
        )
        XCTAssertEqual(
            baseEventProperties["string"] as! String,
            "stringValue"
        )
        XCTAssertEqual(
            baseEventProperties["array"] as! Array,
            [1, 2, 3]
        )
        XCTAssertEqual(
            baseEventPlan["branch"],
            "test-branch"
        )
        XCTAssertEqual(
            baseEventPlan["source"],
            "test-source"
        )
        XCTAssertEqual(
            baseEventPlan["version"],
            "test-version"
        )
        XCTAssertEqual(
            baseEventPlan["versionId"],
            "test-version-id"
        )
        XCTAssertEqual(
            baseEventIngestionMetadata["source_name"],
            "test-source-name"
        )
        XCTAssertEqual(
            baseEventIngestionMetadata["source_version"],
            "test-source-version"
        )
    }

    func testToString_withNilValues() throws {
        let baseEvent = BaseEvent(
            platform: nil,
            eventType: "test",
            eventProperties: [
                "integer": 1,
                "string": nil,
                "array": nil,
            ]
        )

        let baseEventData = baseEvent.toString().data(using: .utf8)!
        let baseEventDict =
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: baseEventData, options: .mutableContainers) as? [String: AnyObject]
            )
        let baseEventProperties = try XCTUnwrap(baseEventDict["event_properties"] as? [String: AnyObject])
        XCTAssertEqual(
            baseEventDict["event_type"] as! String,
            "test"
        )
        XCTAssertEqual(
            baseEventDict["platform"] as? String?,
            nil
        )
        XCTAssertEqual(
            baseEventProperties["integer"] as! Int,
            1
        )
        XCTAssertEqual(
            baseEventProperties["string"] as? String,
            nil
        )
        XCTAssertEqual(
            baseEventProperties["array"] as? [Double],
            nil
        )
    }

    func testFromString() {
        let eventString = """
            {
                "event_type": "test",
                "user_id": "test-user",
                "device_id": "test-device",
                "time": 1670030478000,
                "event_properties": {
                    "integer": 1,
                    "string": "stringValue",
                    "array": [1, 2, 3]
                },
                "plan": {
                    "branch": "test-branch",
                    "source": "test-source",
                    "version": "test-version",
                    "versionId": "test-version-id",
                },
                "ingestion_metadata": {
                    "source_name": "test-source-name",
                    "source_version": "test-source-version"
                }
            }
            """

        let event = BaseEvent.fromString(jsonString: eventString)
        XCTAssertEqual(event?.eventType, "test")
        XCTAssertEqual(event?.userId, "test-user")
        XCTAssertEqual(event?.deviceId, "test-device")
        XCTAssertEqual(event?.timestamp, 1_670_030_478_000)
        XCTAssertEqual(
            event?.eventProperties!["integer"] as! Int,
            1
        )
        XCTAssertEqual(
            event?.eventProperties!["string"] as! String,
            "stringValue"
        )
        XCTAssertEqual(
            event?.eventProperties!["array"] as! [Double],
            [1, 2, 3]
        )
        XCTAssertEqual(
            event?.plan?.branch,
            "test-branch"
        )
        XCTAssertEqual(
            event?.plan?.source,
            "test-source"
        )
        XCTAssertEqual(
            event?.plan?.version,
            "test-version"
        )
        XCTAssertEqual(
            event?.plan?.versionId,
            "test-version-id"
        )
        XCTAssertEqual(
            event?.ingestionMetadata?.sourceName,
            "test-source-name"
        )
        XCTAssertEqual(
            event?.ingestionMetadata?.sourceVersion,
            "test-source-version"
        )
    }

    func testFromString_withNullValues() {
        let eventString = """
            {
                "event_type": "test",
                "user_id": "test-user",
                "device_id": "test-device",
                "time": 1670030478000,
                "platform": null,
                "event_properties": {
                    "integer": 1,
                    "string": null,
                    "array": null
                }
            }
            """

        let event = BaseEvent.fromString(jsonString: eventString)
        XCTAssertEqual(event?.eventType, "test")
        XCTAssertEqual(event?.userId, "test-user")
        XCTAssertEqual(event?.deviceId, "test-device")
        XCTAssertEqual(event?.timestamp, 1_670_030_478_000)
        XCTAssertEqual(event?.platform, nil)
        XCTAssertEqual(
            event?.eventProperties!["integer"] as! Int,
            1
        )
        XCTAssertEqual(
            event?.eventProperties!["string"] as? String?,
            nil
        )
        XCTAssertEqual(
            event?.eventProperties!["array"] as? [Double]?,
            nil
        )
    }

    func testMergeEventOptionsToEvent() {
        let event = BaseEvent(
            userId: "userId-event",
            deviceId: "deviceId-event",
            sessionId: 111,
            city: "city-event",
            eventType: "eventType-event"
        )

        let eventOptions = EventOptions(
            userId: "userId-options",
            sessionId: -1,
            country: "country-options",
            city: "city-options"
        )

        event.mergeEventOptions(eventOptions: eventOptions)

        XCTAssertEqual(event.userId, "userId-options")
        XCTAssertEqual(event.deviceId, "deviceId-event")
        XCTAssertEqual(event.sessionId, -1)
        XCTAssertEqual(event.country, "country-options")
        XCTAssertEqual(event.city, "city-options")
        XCTAssertEqual(event.eventType, "eventType-event")
    }

    func testMergeEventOptionsToOptions() {
        let options = EventOptions(
            userId: "userId",
            deviceId: "deviceId",
            sessionId: 111,
            city: "city"
        )

        let sourceOptions = EventOptions(
            userId: "userId-options",
            sessionId: -1,
            country: "country-options",
            city: "city-options"
        )

        options.mergeEventOptions(eventOptions: sourceOptions)

        XCTAssertEqual(options.userId, "userId-options")
        XCTAssertEqual(options.deviceId, "deviceId")
        XCTAssertEqual(options.sessionId, -1)
        XCTAssertEqual(options.country, "country-options")
        XCTAssertEqual(options.city, "city-options")
    }
}
// swiftlint:enable force_cast
