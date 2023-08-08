//
//  IdentifyEventTests.swift
//
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import AmplitudeSwift

final class IdentifyEventTests: XCTestCase {
    func testInit() {
        let identifyEvent = IdentifyEvent()
        XCTAssertEqual(identifyEvent.eventType, "$identify")
    }
}
