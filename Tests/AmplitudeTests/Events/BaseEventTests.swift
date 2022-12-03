//
//  BaseEventTests.swift
//
//
//  Created by Marvin Liu on 11/23/22.
//

import XCTest

@testable import Amplitude_Swift

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
            baseEventDict!["event_type"] as! String,  // swiftlint:disable:this force_cast
            "test"
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["integer" as NSString] as! Int,  // swiftlint:disable:this force_cast
            1
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["string" as NSString] as! String,  // swiftlint:disable:this force_cast
            "stringValue"
        )
        XCTAssertEqual(
            baseEventDict!["event_properties"]!["array" as NSString] as! Array,  // swiftlint:disable:this force_cast
            [1, 2, 3]
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
            event?.eventProperties!["integer"] as! Int,  // swiftlint:disable:this force_cast
            1
        )
        XCTAssertEqual(
            event?.eventProperties!["string"] as! String,  // swiftlint:disable:this force_cast
            "stringValue"
        )
        XCTAssertEqual(
            event?.eventProperties!["array"] as! [Double],  // swiftlint:disable:this force_cast
            [1, 2, 3]
        )
    }
}
