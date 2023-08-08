//
//  GroupIdentifyEventTests.swift
//
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import AmplitudeSwift

final class GroupIdentifyEventTests: XCTestCase {
    func testInit() {
        let groupIdentifyEvent = GroupIdentifyEvent()
        XCTAssertEqual(groupIdentifyEvent.eventType, "$groupidentify")
    }

    func testIsValid() {
        let groupIdentifyEvent = GroupIdentifyEvent()
        XCTAssertEqual(groupIdentifyEvent.isValid(), false)

        groupIdentifyEvent.groups = ["key": "value"]
        groupIdentifyEvent.groupProperties = ["key": "value"]
    }
}
