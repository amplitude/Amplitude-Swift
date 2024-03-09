//
//  DiagnosticsTests.swift
//  Amplitude-SwiftTests
//
//  Created by Qingzhuo Zhen on 3/4/24.
//

import XCTest

@testable import AmplitudeSwift

final class DiagnosticsTests: XCTestCase {

    func testAddMalformedEvent() {
        let diagnostics = Diagnostics()
        diagnostics.addMalformedEvent("event")
        XCTAssertTrue(diagnostics.hasDiagnostics())
        XCTAssertEqual(diagnostics.extractDiagonostics(), "{\"malformed_events\":[\"event\"]}")
    }

    func testAddErrorLog() {
        let diagnostics = Diagnostics()
        diagnostics.addErrorLog("log")
        XCTAssertTrue(diagnostics.hasDiagnostics())
        XCTAssertEqual(diagnostics.extractDiagonostics(), "{\"error_logs\":[\"log\"]}")
    }

    func testHasDiagonostics() {
        let diagnostics = Diagnostics()
        XCTAssertFalse(diagnostics.hasDiagnostics())
        diagnostics.addMalformedEvent("event")
        XCTAssertTrue(diagnostics.hasDiagnostics())
        diagnostics.addErrorLog("log")
        XCTAssertTrue(diagnostics.hasDiagnostics())
    }

    func testExtractDiagnostic() {
        let diagnostics = Diagnostics()
        XCTAssertEqual(diagnostics.extractDiagonostics(), "")
        diagnostics.addMalformedEvent("event")
        diagnostics.addErrorLog("log")
        XCTAssertEqual(diagnostics.extractDiagonostics(), "{\"malformed_events\":[\"event\"],\"error_logs\":[\"log\"]}")
    }
}
