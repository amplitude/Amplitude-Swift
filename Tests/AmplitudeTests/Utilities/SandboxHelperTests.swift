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
        let sandboxHelper = SandboxHelper()
        let isSandboxed = sandboxHelper.isSandboxEnabled()

        #if os(macOS)
            XCTAssertEqual(isSandboxed, false)
        #else
            XCTAssertEqual(isSandboxed, true)
        #endif
    }

    #if os(macOS)
    func testIsSandboxEnabledWithMacOSAppSandbox() {
        let sandboxHelper = FakeSandboxHelperWithAppSandboxContainer()

        let isSandboxed = sandboxHelper.isSandboxEnabled()

        XCTAssertEqual(isSandboxed, true)
    }
    #endif
}
