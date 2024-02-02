//
//  SandboxHelperTests.swift
//  Amplitude-SwiftTests
//
//  Created by Justin Fiedler on 2/1/24.
//

import XCTest

@testable import AmplitudeSwift

class MockSandboxHelper: SandboxHelper {
    override func getEnvironment() -> Dictionary<String, String> {
        return ["APP_SANDBOX_CONTAINER_ID": "test-container-id"]
    }
}

final class SandboxHelperTests: XCTestCase {

    func testIsSandboxEnabled() {
        let sanboxHelper = SandboxHelper()
        let isSandboxed = sanboxHelper.isSandboxEnabled()

        #if os(macOS)
            XCTAssertEqual(isSandboxed, false)
        #else
            XCTAssertEqual(isSandboxed, true)
        #endif
    }

    #if os(macOS)
    func testIsSandboxEnabledWithMacOSAppSandbox() {
        let sanboxHelper = MockSandboxHelper()
        
        let isSandboxed = SandboxHelper.isSandboxEnabled()

        XCTAssertEqual(isSandboxed, true)
    }
    #endif
}
