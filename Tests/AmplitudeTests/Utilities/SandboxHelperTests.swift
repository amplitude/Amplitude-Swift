//
//  SandboxHelperTests.swift
//  Amplitude-SwiftTests
//
//  Created by Justin Fiedler on 2/1/24.
//

import XCTest

@testable import AmplitudeSwift

final class SandboxHelperTests: XCTestCase {

    func testIsSandboxEnabled() {
        let isSandboxed = SandboxHelper.isSandboxEnabled()

        #if os(iOS)
            XCTAssertEqual(isSandboxed, true)
        #else
            XCTAssertEqual(isSandboxed, false)
        #endif
    }

}
