//
//  RevenueTests.swift
//
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import AmplitudeSwift

// swiftlint:disable force_cast
final class RevenueTests: XCTestCase {
    func testSetProductId_withValidValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.productId, nil)

        revenue.productId = "nice-product"
        XCTAssertEqual(revenue.productId, "nice-product")
    }

    func testSetProductId_withEmptyValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.productId, nil)

        revenue.productId = ""
        XCTAssertEqual(revenue.productId, nil)
    }

    func testSetQuantity_withValidValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.quantity, 1)

        revenue.quantity = 10
        XCTAssertEqual(revenue.quantity, 10)
    }

    func testSetQuantity_withInvalidValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.quantity, 1)

        revenue.quantity = -10
        XCTAssertEqual(revenue.quantity, 1)
    }

    func testSetPrice_withValidValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.price, nil)

        revenue.price = 99.9
        XCTAssertEqual(revenue.price, 99.9)
    }

    func testSetQuantity_withNilValue() {
        let revenue = Revenue()
        revenue.price = 99.9
        XCTAssertEqual(revenue.price, 99.9)

        revenue.price = nil
        XCTAssertEqual(revenue.price, 99.9)
    }

    func testSetRevenue_withValidValue() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.revenue, nil)

        revenue.revenue = 99.9
        XCTAssertEqual(revenue.revenue, 99.9)
    }

    func testSetRevenue_withNilValue() {
        let revenue = Revenue()
        revenue.revenue = 99.9
        XCTAssertEqual(revenue.revenue, 99.9)

        revenue.revenue = nil
        XCTAssertEqual(revenue.revenue, 99.9)
    }

    func testIsValid() {
        let revenue = Revenue()
        XCTAssertEqual(revenue.isValid(), false)

        revenue.price = 10
        XCTAssertEqual(revenue.isValid(), true)
    }

    func testToRevenueEvent() {
        let revenue = Revenue()
        revenue.productId = "good-product"
        revenue.quantity = 100
        revenue.price = 50.5
        revenue.revenueType = "test-type"
        revenue.currency = "USD"
        revenue.receipt = "test-receipt"
        revenue.receiptSig = "test-receipt-sig"
        revenue.revenue = 5050
        let revenueEvent = revenue.toRevenueEvent()

        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_PRODUCT_ID.rawValue] as! String,
            "good-product"
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_QUANTITY.rawValue] as! Int,
            100
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_PRICE.rawValue] as! Double,
            50.5
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_TYPE.rawValue] as! String,
            "test-type"
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_RECEIPT.rawValue] as! String,
            "test-receipt"
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_RECEIPT_SIG.rawValue] as! String,
            "test-receipt-sig"
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE.rawValue] as! Double,
            5050
        )
        XCTAssertEqual(
            revenueEvent.eventProperties?[Revenue.Property.REVENUE_CURRENCY.rawValue] as! String,
            "USD"
        )
    }
}
// swiftlint:enable force_cast
