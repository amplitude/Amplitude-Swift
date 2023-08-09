//
//  TypesTests.swift
//
//
//  Created by Marvin Liu on 12/2/22.
//
//  This file contains implementations in extensions of common types.

import XCTest

@testable import AmplitudeSwift

final class TypesTests: XCTestCase {
    func testResponseHandler_collectIndices() {
        let dataToCollectIndices = [
            "time": [1, 2, 3],
            "event_type": [3, 4],
        ]
        let result = FakeResponseHandler.collectIndices(data: dataToCollectIndices)

        XCTAssertEqual(result, Set([1, 2, 3, 4]))
    }
}
