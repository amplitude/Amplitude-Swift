//
//  RevenueEventTests.swift
//  
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import Amplitude_Swift

final class RevenueEventTests: XCTestCase {
    func testInit() {
        let revenueEvent = RevenueEvent()
        XCTAssertEqual(revenueEvent.eventType, "revenue_amount")
    }
}
