//
//  BaseEventTests.swift
//
//
//  Created by Marvin Liu on 11/23/22.
//

import XCTest

@testable import Amplitude_Swift

// swiftlint:disable force_cast
final class BaseEventTests: XCTestCase {
    func testToString() {
        let baseEvent = BaseEvent(
            eventType: "test",
            eventProperties: [
                "integer": 1,
                "string": "stringValue",
                "array": [1, 2, 3],
            ]
        )

        let baseEventData = baseEvent.toString().data(using: .utf8)!
        let baseEventDict =
            try? JSONSerialization.jsonObject(with: baseEventData, options: .mutableContainers) as? [String: AnyObject]
        XCTAssertEqual(
            baseEventDict!["event_type"] as! String,
            "test"
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["integer" as NSString] as! Int,
            1
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["string" as NSString] as! String,
            "stringValue"
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["array" as NSString] as! Array,
            [1, 2, 3]
        )
    }

    func testToString_withNilValues() {
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
            try? JSONSerialization.jsonObject(with: baseEventData, options: .mutableContainers) as? [String: AnyObject]
        XCTAssertEqual(
            baseEventDict!["event_type"] as! String,
            "test"
        )
        XCTAssertEqual(
            baseEventDict!["platform"] as? String?,
            nil
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["integer" as NSString] as! Int,
            1
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["string" as NSString] as? String,
            nil
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["array" as NSString] as? [Double],
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
}
