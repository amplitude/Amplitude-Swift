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
        let result = convertToDictionary(text: diagnostics.extractDiagonostics())
        XCTAssertEqual(result?["malformed_events"] as! [String], ["event"])
        XCTAssertEqual(result?["error_logs"] as! [String], ["log"])
    }

    private func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
}
