//
//  IdentifyEventTests.swift
//
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import Amplitude_Swift

final class IdentifyEventTests: XCTestCase {
    func testInit() {
        let identifyEvent = IdentifyEvent()
        XCTAssertEqual(identifyEvent.eventType, "$identify")
    }
}
