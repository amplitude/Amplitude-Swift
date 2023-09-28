//
//  IdentifyTests.swift
//
//
//  Created by Marvin Liu on 12/11/22.
//

import XCTest

@testable import AmplitudeSwift

// swiftlint:disable force_cast
final class IdentifyTests: XCTestCase {
    func testSetOperation_withEmptyProperty() {
        let identify = Identify()
        identify.set(property: "", value: "test-value")
        XCTAssertEqual(
            identify.propertySet,
            Set()
        )
        XCTAssertEqual(
            identify.properties as! [String: [String: String]],
            [:]
        )
    }

    func testSetOperation_withNilValue() {
        let identify = Identify()
        identify.set(property: "test-property", value: nil)
        XCTAssertEqual(
            identify.propertySet,
            Set()
        )
        XCTAssertEqual(
            identify.properties as! [String: [String: String]],
            [:]
        )
    }

    func testSetOperation_withExistingClearAllOperation() {
        let identify = Identify()
        identify.clearAll()
        XCTAssertEqual(
            identify.propertySet,
            Set()
        )
        XCTAssertEqual(
            identify.properties as! [String: String],
            [Identify.Operation.CLEAR_ALL.rawValue: Identify.UNSET_VALUE]
        )
        identify.set(property: "test-property", value: "test-value")
        XCTAssertEqual(
            identify.propertySet,
            Set()
        )
        XCTAssertEqual(
            identify.properties as! [String: String],
            [Identify.Operation.CLEAR_ALL.rawValue: Identify.UNSET_VALUE]
        )
    }

    func testSetOperation_withValidValue() {
        let identify = Identify()
        identify.set(property: "test-property", value: "test-value")
        XCTAssertEqual(
            identify.propertySet,
            Set(["test-property"])
        )
        XCTAssertEqual(
            identify.properties as! [String: [String: String]],
            [Identify.Operation.SET.rawValue: ["test-property": "test-value"]]
        )
    }

    func testUnsetOperation_withValidValue() {
        let identify = Identify()
        identify.unset(property: "test-property")
        XCTAssertEqual(
            identify.propertySet,
            Set(["test-property"])
        )
        XCTAssertEqual(
            identify.properties as! [String: [String: String]],
            [Identify.Operation.UNSET.rawValue: ["test-property": Identify.UNSET_VALUE]]
        )
    }
}
// swiftlint:enable force_cast
